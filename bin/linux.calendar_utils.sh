## "@(#) $Id: macOSX.Apple_ccs_to_vjpd_ccs_migration 3991 2022-03-14 10:07:32Z vdoublie $"

__pwd=$(pwd)
_SUDO=$(which sudo 2>/dev/null)
_SUDO_ccs_user=${_SUDO:+${_SUDO} -u ${ccs_user}}
################################################################################
# Before building...
pre_build() {
  cd ${__pwd}
  ## Stop any running instance of the Calendar & Contacts
  if which serveradmin > /dev/null 2>&1 ; then
    execCmd "${_SUDO:+${_SUDO} }serveradmin stop calendar"
    execCmd "${_SUDO:+${_SUDO} }serveradmin stop addressbook"
  fi
  if [ -e /Library/LaunchDaemons/org.calendarserver.plist ]; then
    execCmd "${_SUDO:+${_SUDO} }launchctl unload -w /Library/LaunchDaemons/org.calendarserver.plist"
    execCmd "${_SUDO:+${_SUDO} }rm /Library/LaunchDaemons/org.calendarserver.plist"
  fi
  if [ -h /Library/LaunchDaemons/org.calendarserver.plist ]; then
    execCmd "${_SUDO:+${_SUDO} }rm /Library/LaunchDaemons/org.calendarserver.plist"
  fi

  # Create an admin ${ccs_user:-calendarserver} user and group if necessary
  ## Some interesting things here...
  ## https://github.com/essandess/macOS-Open-Source-Server/blob/master/macOS%20Server%20Migration%20Notes.md#calendar-and-contacts
  if [ $(uname) != "Linux" ] ; then
    if ! dscl . -list /Users | grep ^${ccs_user}$ > /dev/null 2>&1 ; then
      # see https://gist.github.com/steakknife/941862
      ## Next free UID and GID starting at 200...
      NEXTUID=$(dscl . -list /Users UniqueID | sort -n -k2 | awk 'BEGIN{i=200}{if($2==i)i=$2+1}END{print i}')
      NEXTGID=$(dscl . -list /Groups UniqueID | sort -n -k2 | awk 'BEGIN{i=200}{if($2==i)i=$2+1}END{print i}')
      # First create the group, if needed...
      if ! dscl . -list /Groups | grep ^${ccs_group:-${ccs_user}}$ > /dev/null 2>&1 ; then
        execCmd "${_SUDO:+${_SUDO} }dscl . -create /Groups/${ccs_group:-${ccs_user}} \
          PrimaryGroupID ${NEXTGID} \
        "
        execCmd "${_SUDO:+${_SUDO} }dscl . -create /Groups/${ccs_group:-${ccs_user}} \
          RecordName ${ccs_group:-${ccs_user}} \
        "
      fi
      # Then the user...
      execCmd "${_SUDO:+${_SUDO} }dscl . -create /Users/${ccs_user} \
        RealName ${ccs_user} \
      "
      execCmd "${_SUDO:+${_SUDO} }dscl . -create /Users/${ccs_user} \
        UniqueID ${NEXTUID} \
      "
      execCmd "${_SUDO:+${_SUDO} }dscl . -create /Users/${ccs_user} \
        PrimaryGroupID ${ccs_group:-${ccs_user}} \
      "
      execCmd "${_SUDO:+${_SUDO} }dscl . -create /Users/${ccs_user} \
        NFSHomeDirectory /private/var/${ccs_user} \
      "
      execCmd "${_SUDO:+${_SUDO} }dscl . -create /Users/${ccs_user} \
        UserShell /bin/bash \
      "
    fi
    execCmd "${_SUDO:+${_SUDO} }mkdir -p /private/var/${ccs_user}"
    execCmd "${_SUDO:+${_SUDO} }chown -R ${ccs_user}:${ccs_group:-${ccs_user}} /private/var/${ccs_user}"
    execCmd "${_SUDO:+${_SUDO} }chmod 0750 /private/var/${ccs_user}"
    for G in certusers _postgres ; do
      if ! dscl . -read /Groups/${G} GroupMembership | grep ${ccs_user}  > /dev/null 2>&1 ; then
        execCmd "${_SUDO:+${_SUDO} }dscl . -append /Groups/${G} GroupMembership ${ccs_user}"
      fi
    done
  fi
}
################################################################################
# Build
build_server() {
  cd ${__pwd}
  _pwd=$(pwd)
  ! grep PATH.\*${_pwd}}/Library/Python/2.7/bin .profile >/dev/null 2>&1 && \
    execCmd "echo 'export PATH=${_pwd}/Library/Python/2.7/bin:$(getconf PATH)' > .profile"
  . .profile

  execCmd "mkdir -pv git"
  ccs_ver=${ccs_ver:-9.4.4-dev}
  if [ ! -d git/ccs-calendarserver-${ccs_ver} ]; then
    #git clone https://github.com/apple/ccs-calendarserver.git git/ccs-calendarserver-HEAD
    execCmd "git clone -b release/CalendarServer-${ccs_ver} https://github.com/JohnPritchard/ccs-calendarserver.git git/ccs-calendarserver-${ccs_ver}"
  else
    execCmd "cd git/ccs-calendarserver-${ccs_ver}"
    execCmd "git pull"
    execCmd "cd"
  fi

  cd "${_pwd}"
  for D in ${ccs_ver} ccs-calendarserver CalendarServer CalendarServer-${ccs_ver} ; do
    [ -d $D ] && execCmd "rm -fr $D"
    [ -h $D ] && execCmd "rm $D"
  done
  [ ! -d "${_pwd}"/ccs-pkgs ] && mkdir -v "${_pwd}"/ccs-pkgs
  execCmd "mkdir ${ccs_ver}"
  execCmd "rsync -ax git/ccs-calendarserver-${ccs_ver}/ ${ccs_ver}/ccs-calendarserver/"
  cd ${ccs_ver}
  execCmd "mkdir ccs-calendarserver/.develop"
  execCmd "ln -s ${_pwd}/ccs-pkgs ccs-calendarserver/.develop/pkg"
  execCmd "chmod -R g+rwX ccs-calendarserver"
  # Install pip
  execCmd "mkdir ccs-calendarserver/.develop/ve_tools"
  execCmd "curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py"
  execCmd "env -i PYTHONUSERBASE='ccs-calendarserver/.develop/ve_tools' ${PYTHON:-python} get-pip.py"
  # Build server...
  execCmd "cd ccs-calendarserver"
  execCmd "env -i \
    PATH=$(getconf PATH) \
    ${PYTHON:+PYTHON=${PYTHON}} \
    USE_OPENSSL=1 \
    bash -x ./bin/package ${_pwd}/${ccs_ver}/CalendarServer \
    "
  [ -h "${_pwd}/CalendarServer" ] && execCmd "rm ${_pwd}/CalendarServer"
  execCmd "ln -fsv ${ccs_ver}/CalendarServer ${_pwd}/CalendarServer"
}
################################################################################
# Configure
configure_server() {
  cd ${__pwd}
  _pwd=$(pwd)
  # In a container env, conf as part of the container,
  # certs, logs & run on the bound volume ${CCS_ROOT}/Calendar_and_Contacts
  # that we can't do anything about at the time of creating the container...
  execCmd "mkdir -p /var/calendarserver/conf"
  execCmd "chown -R calendarserver:calendarserver /var/calendarserver"
  execCmd "chmod -R 0750 /var/calendarserver"
  execCmd "${VJPD_FUNCTIONS_SED} \
    -e \"s@/Library/Server/Calendar and Contacts@${CCS_ROOT}/Calendar_and_Contacts@\" \
    -e 's@<string>/Library/Server/Preferences/Calendar.plist</string>@<!-- & -->@' \
    -e 's@8008@9008@' \
    -e 's@8443@9443@' \
    ${_pwd}/${ccs_ver}/ccs-calendarserver/contrib/conf/calendarserver.plist \
    > /var/calendarserver/conf/calendarserver.plist \
    "
  execCmd "cp ${_pwd}/${ccs_ver}/ccs-calendarserver/contrib/conf/org.calendarserver.plist \
    /var/calendarserver/conf \
    "
  execCmd "${VJPD_FUNCTIONS_SED} -i \
    -e \"s@/Users/calendarserver/CalendarServer@${CCS_ROOT}/Calendar_and_Contacts@g\" \
    /var/calendarserver/conf/* \
  "

  # nginx reverse proxy configuration
  mkdir -p /var/calendarserver/etc
  vi /var/calendarserver/etc/nginx.conf
  mkdir -p /var/calendarserver/etc/nginx_root
  vi /var/calendarserver/etc/nginx_root/default.html  # unused, but nginx root is here
  openssl dhparam -out /var/calendarserver/etc/dhparam.pem 4096

  ### From...
  ### https://github.com/essandess/macOS-Open-Source-Server/blob/master/macOS%20Server%20Migration%20Notes.md#calendar-and-contacts
  if false ; then
# Configuration
mkdir -p /var/calendarserver/Library/CalendarServer/Config
chgrp _calendar /var/calendarserver/Library/CalendarServer/Config
chmod 0750 /var/calendarserver/Library/CalendarServer/Config

# Logs
mkdir -p /var/calendarserver/Library/CalendarServer/logs
chgrp _calendar /var/calendarserver/Library/CalendarServer/logs
chmod 0750 /var/calendarserver/Library/CalendarServer/logs

# PostgreSQL
mkdir -p /var/calendarserver/Library/CalendarServer/Data/Database
chgrp -R _calendar /var/calendarserver/Library/CalendarServer/Data
chmod -R 0700 /var/calendarserver/Library/CalendarServer/Data

# calendarserver config file
vi /var/calendarserver/Library/CalendarServer/Config/calendarserver.plist

# nginx reverse proxy configuration
mkdir -p /var/calendarserver/Library/CalendarServer/etc
vi /var/calendarserver/Library/CalendarServer/etc/nginx.conf
mkdir -p /var/calendarserver/Library/CalendarServer/etc/nginx_root
vi /var/calendarserver/Library/CalendarServer/etc/nginx_root/default.html  # unused, but nginx root is here
openssl dhparam -out /var/calendarserver/Library/CalendarServer/etc/dhparam.pem 4096

# Launch daemons
mkdir -p /var/calendarserver/Library/CalendarServer/Config/LaunchDaemons
vi /var/calendarserver/Library/CalendarServer/Config/LaunchDaemons/org.calendarserver.calendarserver.plist
vi /var/calendarserver/Library/CalendarServer/Config/LaunchDaemons/org.calendarserver.nginx_proxy.plist

# ccs-calendarserver's postgres code points to `PSQL = "../postgresql/_root/bin/psql"`
mkdir -p /var/calendarserver/Library/CalendarServer/postgresql
ln -s /opt/local /var/calendarserver/Library/CalendarServer/postgresql/_root

  sudo sh -x <<CALENDARSERVER_SPECIFICS
mkdir /var/run/caldavd
chown -R calendarserver:_calendar /var/run/caldavd
chmod 0770 /var/run/caldavd
mkdir /var/run/caldavd_requests
chown -R calendarserver:_calendar /var/run/caldavd_requests
chmod -R 0770 /var/run/caldavd_requests
CALENDARSERVER_SPECIFICS
  fi
}
################################################################################
# Create self-signed Certificates
create_self_signed_certs() {
  cd ${__pwd}
  _pwd=$(pwd)
  execCmd "cd "${_pwd}"/CalendarServer/certs" || exit 1
  cert_dt=$(date +%Y-%m-%dT%H:%M:%S%z)
  execCmd "mkdir $cert_dt" || exit 1
  ## using self signed certificates...
  ## see https://7402.org/blog/2019/new-self-signed-ssl-cert-ios-13.html
  ## Modified for using the openssl built by ccs-calendarserver...
  execCmd "cp ../roots/openssl/ssl/openssl.cnf ${cert_dt}/${_hostname_s}.cnf"
  execCmd "${VJPD_FUNCTIONS_SED} -i\
    -e \"s/^\[\s\s*v3_ca\s\s*\]\s*$/&\nsubjectAltName = DNS:${_hostname_s}.vjpd.net\nextendedKeyUsage = serverAuth\n/\" \
    -e 's/^# \(copy_extensions = copy\)/\1/' \
    ${cert_dt}/${_hostname_s}.cnf \
    " || exit 1
  execCmd "../bin/openssl \
    req -x509 -nodes -days 825 -newkey rsa:2048 \
    -config ${cert_dt}/${_hostname_s}.cnf \
    -keyout $cert_dt/calendarserver.key.pem \
    -out $cert_dt/calendarserver.cert.pem \
    -subj \"/C=DE/ST=By/L=Neubiberg/O=vjpd/CN=vimes.vjpd.net\" \
    " || exit 1
  [ -e current ] && execCmd "rm -v current"
  execCmd "ln -s $cert_dt current" || exit 1
  [ ! -e calendarserver.cert.pem ] && execCmd "ln -s current/calendarserver.cert.pem calendarserver.cert.pem" 
  [ ! -e calendarserver.key.pem ] && execCmd "ln -s current/calendarserver.key.pem calendarserver.key.pem" 
  [ ! -e calendarserver.chain.pem ] && execCmd "ln -s calendarserver.cert.pem calendarserver.chain.pem"
  execCmd "cd '${_pwd}'"
}
################################################################################
################################################################################
# Upgrade postgresql DB from 9.4 to 9.5/13.1...
# If the old_PG_VERSION < the server's PG version, we need to upgrade...
upgrade_database() {
  cd ${__pwd}

  ## An existing database...
  # If it exists, extract a tgz Archive version of the database...
  if [ ! -z "${ccs_tarfile}" ]; then
    if [ -e "${ccs_tarfile}" ]; then
      [ -d ${CCS_ROOT}/Calendar_and_Contacts ] && execCmd "${_SUDO:+${_SUDO} }rm -fr ${CCS_ROOT}/Calendar_and_Contacts"
      execCmd "${_SUDO:+${_SUDO} }tar -C ${CCS_ROOT} -zxf '${ccs_tarfile}'"
    else
      errorLog "Could not find '${ccs_tarfile}'"
      exit 1
    fi
  fi
  # Set ownerships to ${ccs_user} user...
  if [ -d ${CCS_ROOT}/Calendar_and_Contacts ]; then
    execCmd "${_SUDO:+${_SUDO} }chown -R ${ccs_user}:${ccs_group:-${ccs_user}} ${CCS_ROOT}/Calendar_and_Contacts"
  fi
  if [ -d /var/run/caldavd ]; then
    execCmd "${_SUDO:+${_SUDO} }find /var/run/caldavd -user _calendar -exec chown ${ccs_user}:${ccs_group:-${ccs_user}} {} \\;"
    #find /var/run/caldavd -user ${ccs_user} -exec chown _calendar:_calendar {} \;
  fi

  # Check postgresql version...
  if [ -d ${CCS_ROOT}/Calendar_and_Contacts ]; then
    if [ -e "${CLUSTER}/PG_VERSION" ]; then
      old_PG_VERSION=$(cat "${CLUSTER}/PG_VERSION")
    fi
  fi
  if [ ! -z ${old_PG_VERSION} ]; then
    # Get the version of the server's PG...
    # calendarserver-postgresql version
    BIN_DIR_to="$(eval echo ~${ccs_user}/CalendarServer/roots/PostgreSQL/bin)"
    to_ver=$($BIN_DIR_to/pg_ctl -V | awk '{print $3}')
    to_PG_VERSION=$(echo ${to_ver} | sed -e 's/\.[0-9][0-9]*$//')
    if (( $(echo "${old_PG_VERSION} < ${to_PG_VERSION}" | bc -l) )); then
      notQuietLog "Database needs to be upgraded, from PG_VERSION=${old_PG_VERSION} to ${to_PG_VERSION}..."
      unset LC_CTYPE
      DT=${DT:-$(date +%Y-%m-%dT%H:%M:%S)}

      # Find ${old_PG_VERSION}
      if [ -z "${BIN_DIR_from}" ]; then
        old_PG_VERSION_no_dots=${old_PG_VERSION//./}
        if [ -d "/Applications/Server.app/Contents/ServerRoot/usr/bin" ]; then
          BIN_DIR_from="/Applications/Server.app/Contents/ServerRoot/usr/bin"
        elif [ -d "/opt/local/lib/vjpd-postgresql${old_PG_VERSION_no_dots}/bin" ]; then
          BIN_DIR_from="/opt/local/lib/vjpd-postgresql${old_PG_VERSION_no_dots}/bin"
        elif [ -d "/opt/local/lib/postgresql${old_PG_VERSION_no_dots}/bin" ]; then
          BIN_DIR_from="/opt/local/lib/postgresql${old_PG_VERSION_no_dots}/bin"
        else
          errorLog "Could not find a postgresql${old_PG_VERSION_no_dots} installation"
          exit 1
        fi
      fi
      from_ver=$($BIN_DIR_from/pg_ctl -V | awk '{print $3}')
      from_PG_VERSION=$(echo ${from_ver} | sed -e 's/\.[0-9][0-9]*$//')
      from_PG_VERSION_no_dots=${from_PG_VERSION//./}
      if (( $(echo "${old_PG_VERSION} != ${from_PG_VERSION}" | bc -l) )); then
        errorLog "postgresql${from_PG_VERSION_no_dots} version can not be used with postgresql${old_PG_VERSION_no_dots} database"
        exit 1
      fi

      execCmd "cd \"${dn_CLUSTER}\""
      # Check the version of the current cluster...
      # Dump the 9.4 DB using the macos Server postgres-9.4, just in case...
      if [ ! -d "${CLUSTER}-${from_PG_VERSION}" ] ; then
        execCmd "${ccs_user:+${_SUDO_ccs_user}} \
          \"${BIN_DIR_from}/pg_ctl\" \
            -U caldav \
            -l caldav.dump-${from_ver}.${DT}.log \
            -D \"${CLUSTER}\" \
            -w start \
            "
        execCmd "${ccs_user:+${_SUDO_ccs_user}} \
          \"${BIN_DIR_from}/pg_dump\" \
            -U caldav \
            -b caldav \
            -f \"${dn_CLUSTER}/caldav.dump-${from_ver}.${DT}.out\" \
            "
        execCmd "${ccs_user:+${_SUDO_ccs_user}} \
          \"${BIN_DIR_from}/pg_ctl\" \
            -U caldav \
            -l caldav.dump-${from_ver}.${DT}.log \
            -D \"${CLUSTER}\" \
            -w stop \
            "
      fi
      # Upgrade to calendarserver-postgresql version
      #BIN_DIR_to=${_pwd}/CalendarServer/roots/PostgreSQL/bin
      # Upgrade to postgresql 9.5
      #BIN_DIR_to="/opt/local/lib/postgresql95/bin"
      # Upgrade to postgresql 13
      #BIN_DIR_to="/opt/local/lib/postgresql13/bin"

      execCmd "mv ${vbose} \"${CLUSTER}\" \"${CLUSTER}-${from_PG_VERSION}\""
      if [ -d "${CLUSTER}-${from_PG_VERSION}" ] ; then
        [ -d postres_upgrade ] && execCmd "rm -fr postres_upgrade"
        execCmd "mkdir -p postres_upgrade"
        execCmd "cd postres_upgrade"
        execCmd "${ccs_user:+${_SUDO_ccs_user}} \
          \"${BIN_DIR_to}/initdb\" \
            -D \"${CLUSTER}\" \
            -U caldav \
            -E UTF8 \
            2>&1 | tee -a caldav_upgrade_${from_ver}--${to_ver}.log \
            "
        [ ! -z "${ccs_user}" ] && ${_SUDO:+${_SUDO} }chown -R ${ccs_user}:${ccs_group:-${ccs_user}} "${CCS_ROOT}/Calendar_and_Contacts"
        execCmd "${ccs_user:+${_SUDO_ccs_user}} \
          \"${BIN_DIR_to}/pg_upgrade\" -v \
            -U caldav \
            -b \"${BIN_DIR_from}\" \
            -B \"${BIN_DIR_to}\" \
            -d \"${CLUSTER}-${from_PG_VERSION}\" \
            -D \"${CLUSTER}\" \
            2>&1 | tee -a caldav_upgrade_${from_ver}--${to_ver}.log \
            "
        execCmd "${ccs_user:+${_SUDO_ccs_user}} \
          \"${BIN_DIR_to}/pg_ctl\" \
            -D \"${CLUSTER}\" \
            -l caldav_upgrade_${from_ver}--${to_ver}.log \
            -w start \
            "
        if [ ! -e ./analyze_new_cluster.sh ]; then
          errorLog "Something went wrong, analyze_new_cluster.sh does not exist."
          exit 1
        fi
        execCmd "./analyze_new_cluster.sh | tee -a caldav_upgrade_${from_ver}--${to_ver}.log"
        execCmd "${ccs_user:+${_SUDO_ccs_user}} \
          \"${BIN_DIR_to}/pg_ctl\" \
            -D \"${CLUSTER}\" \
            -l caldav_upgrade_${from_ver}--${to_ver}.log \
            -w stop \
            "
        execCmd "cd .."
        [ -d postres_upgrade_${from_ver}--${to_ver}.${DT} ] && execCmd "rm -fr postres_upgrade_${from_ver}--${to_ver}.${DT}"
        execCmd "mv postres_upgrade postres_upgrade_${from_ver}--${to_ver}.${DT}"
      fi
      #if [ -d "${CLUSTER}" ]; then
      #  cd "${CLUSTER}"
      #  [ ! -e postgresql.conf.orig ] && mv postgresql.conf postgresql.conf.orig
      #  touch postgresql.conf
      #fi
    fi
  fi
}
################################################################################
## Enable in launchctl
enable_in_launchctl() {
  cd ${__pwd}
  cd ~calendarserver/${ccs_ver}/CalendarServer/conf
  execCmd "chown root:wheel org.calendarserver.plist"
  if [ ! -e /Library/LaunchDaemons/org.calendarserver.plist ] || \
    ! diff org.calendarserver.plist /Library/LaunchDaemons/org.calendarserver.plist >/dev/null 2>&1 ; \
    then
      execCmd "${_SUDO:+${_SUDO} }ln -fsv $(pwd)/org.calendarserver.plist /Library/LaunchDaemons/"
  fi
  printf "\
Enable with:
${_SUDO:+${_SUDO} }launchctl load -w /Library/LaunchDaemons/org.calendarserver.plist 
Disable with...
${_SUDO:+${_SUDO} }launchctl unload -w /Library/LaunchDaemons/org.calendarserver.plist
"
}
################################################################################
