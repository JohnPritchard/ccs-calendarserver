## "@(#) $Id: vjpd.functions.sh 4741 2024-10-06 12:50:35Z jpritcha $"

################################################################################
## Provides:

#  checkVarIsSet()
#  countdown() <secs>
#  datetime()
#  dbgCont()
#  debugLog()
#  errorLog()
#  execCmd()
#  execCmdDebug()
#  execCmdDryRun()
#  execCmdIgnoreDryRun()
#  execCmdExitOnError()
#  execCmdExitOnErrorIgnoreDryRun()
#  get_mp4tag() <file> <tag> --> <value>
#  imageDB_shasum() <img>
#  imageDB_dtasi() <img>
#  notQuietLog()
#  setDebug()
#  setDryRun()
#  setQuiet()
#  setVbose()
#  toUseTheseFunction()
#  verboseLog()
#  warningLog()

################################################################################
## To Use insert the contents of the following funtion in the script:

toUseTheseFunction() {
################################################################################
## Generic utility functions
if [ -z "${VJPD_FUNCTIONS_READLINK}" ]; then
  VJPD_FUNCTIONS_READLINK="readlink"
  which greadlink > /dev/null 2>&1 && VJPD_FUNCTIONS_READLINK="greadlink"
  if ! ${VJPD_FUNCTIONS_READLINK} -f ${0} >/dev/null 2>&1 ; then
    echo "${VJPD_FUNCTIONS_READLINK} does not support -f command line option"
    exit 1
  fi
fi
[ -z "${VJPD_FUNCTIONS}" ] && VJPD_FUNCTIONS="$(ls $(dirname $(${VJPD_FUNCTIONS_READLINK} -f \"${0}\"))/vjpd.functions.sh 2>/dev/null)"
if [ -e ${VJPD_FUNCTIONS:-/opt/vjpd/bin/vjpd.functions.sh} ]; then
  . ${VJPD_FUNCTIONS:-/opt/vjpd/bin/vjpd.functions.sh}
else
  echo "${execName}::Error:: ${VJPD_FUNCTIONS:-/opt/vjpd/bin/vjpd.functions.sh} does NOT exist"
  exit 1
fi
# ------------------------------------------------------------------------------
}

################################################################################
## Make sure the relevant directory is in the PATH
if [ -z "${VJPD_FUNCTIONS_READLINK}" ]; then
  VJPD_FUNCTIONS_READLINK="readlink"
  which greadlink > /dev/null 2>&1 && VJPD_FUNCTIONS_READLINK="greadlink"
fi
canonical_exec=$(${VJPD_FUNCTIONS_READLINK} -f "${0}" 2>/dev/null)
if [ ! -z "${canonical_exec}" ]; then
  execPATH=$(dirname "${canonical_exec}")
  if [[ ! "${PATH}" =~ "${execPATH}" ]]; then
    export PATH=${execPATH}:${PATH}
  fi
fi

################################################################################
## Useful environment variables
if [ -z "${VJPD_FUNCTIONS_DATE}" ]; then
  VJPD_FUNCTIONS_DATE="date"
  which gdate > /dev/null 2>&1 && VJPD_FUNCTIONS_DATE="gdate"
  export VJPD_FUNCTIONS_DATE
fi
if [ -z "${VJPD_FUNCTIONS_SED}" ]; then
  VJPD_FUNCTIONS_SED="sed"
  which gsed > /dev/null 2>&1 && VJPD_FUNCTIONS_SED="gsed"
  export VJPD_FUNCTIONS_SED
fi
SED="sed"
which ssed > /dev/null 2>&1 && SED="ssed"

################################################################################
verboseLog() {
  if [ ! -z "${vbose}" ]
  then
    echo "${execName}:: $1" >> ${2:-/dev/stdout}
  fi
}

################################################################################
debugLog() {
  if [ ! -z "${debug}" ]
  then
    echo "${execName}::debug:: $1" >> ${2:-/dev/stdout}
  fi
}

################################################################################
notQuietLog() {
  if [ -z "${quiet}" ]
  then
    echo "${execName}:: $1" >> ${2:-/dev/stdout}
  fi
}

################################################################################
errorLog() {
  if [ ${quietLevel:-0} -lt 3 ]
  then
    echo "${execName}::Error:: $1" >> ${2:-/dev/stderr}
  fi
}

################################################################################
warningLog() {
  if [ ${quietLevel:-0} -lt 2 ]
  then
    echo "${execName}::Warning:: $1" >> ${2:-/dev/stderr}
  fi
}

################################################################################
execCmd() {
  if [ ! -z "${debug}" ] || [ ! -z "${dryRun}" ] || [ ! -z "${ECdebug}" ] || [ ! -z "${ECdryRun}" ] && [ -z "${quiet}" ]
  then
    echo "${execName}::execCmd:: $1"
  fi
  unset execCmd_PIPESTATUS
  if [ -z "${dryRun}"  ] && [ -z "${ECdryRun}" ] || ${ignoreDryRun:-false}
  then
    unsetIgnoreDryRun="${ignoreDryRun:-true}"
    unset ignoreDryRun
    local i=0 S
    if echo "${1}" | grep '&[[:space:]]*$' >/dev/null 2>&1 ; then
      echo eval "${1}"
      return 0
    else
      eval "${1} ; for S in \${PIPESTATUS[@]} ; do execCmd_PIPESTATUS[\$i]=\$S ; (( i++ )) ; done"
    fi
    ${unsetIgnoreDryRun:-false} && unset ignoreDryRun
    return ${execCmd_PIPESTATUS[((${#execCmd_PIPESTATUS[@]}-1))]}
  fi
  execCmd_PIPESTATUS=0
  return 0
}

################################################################################
execCmdDebug() {
  ECdebug="--debug"
  execCmd "${1}"
  retval=$?
  unset ECdebug
  return $retval
}

################################################################################
execCmdDryRun() {
  ECdryRun="--dryRun"
  execCmd "${1}"
  retval=$?
  unset ECdryRun
  return $retval
}

################################################################################
execCmdIgnoreDryRun() {
  unsetIgnoreDryRun="${ignoreDryRun:-true}"
  ignoreDryRun="true"
  execCmd "${1}"
  retval=$?
  ${unsetIgnoreDryRun:-false} && unset ignoreDryRun
  return $retval
}

################################################################################
execCmdExitOnErrorIgnoreDryRun() {
  unsetIgnoreDryRun="${ignoreDryRun:-true}"
  ignoreDryRun="true"
  execCmdExitOnError "${1}"
  retval=$?
  ${unsetIgnoreDryRun:-false} && unset ignoreDryRun
  return $retval
}
################################################################################
execCmdExitOnError() {
  execCmd "${1}"
  local i=1 j S estat=0
  for S in ${execCmd_PIPESTATUS[@]} ; do
    if [ $S -ne 0 ]; then
      if [ ${#execCmd_PIPESTATUS[@]} -gt 1 ]; then
        unset preDel postDel 
        (( j=i+1 ))
        (( k=i-1 ))
        [ $i -gt 1 ] && preDel=" -e 1,${k}d"
        [ $i -lt ${#execCmd_PIPESTATUS[@]} ] && postDel=" -e ${j},${#execCmd_PIPESTATUS[@]}d"
        errorLog "'$(echo ${1} | tr '|' '\n' | sed${preDel}${postDel} -e 's/^ *//' -e 's/ *$//')', exited with status $S"
      else
        errorLog "'${1}' failed, exited with status $S"
      fi
      estat=$S
      (( i++ ))
    fi
  done
  [ $estat -ne 0 ] && exit $estat
}

################################################################################
## Usage:
## checkVarIsSet <VAR-NAME> <level> [error-message] [exit-status]
##      <VAR-NAME>: name of variable to check for, no '$'
##         <level>: fatal|fatalNoExit|warn
## [error-message]: Optional Error/Warning message to print
##   [exit-status]: Optional exit status value
##
checkVarIsSet(){
  v1="$`echo $1`"
  v2="`eval echo $v1`"
  debugLog "Variable $1 is set to $v2"
  if [ -z "${v2}" ]
  then
    debugLog "Variable $1 is not set"
    case $2 in
      fatal)       errorLog   "${3:-Variable $1 not set}"; exstat=${4:-1} ; usage ;;
      fatalNoExit) errorLog   "${3:-Variable $1 not set}"; (( exstat=${exstat-0}+${4:-1} ));;
      warn)        warningLog "${3:-Variable $1 not set}";;
      *)           errorLog   "*** Coding error:: error-level not recognised"; exit 1
    esac
  else
    debugLog "Variable $1 is set to $v2"
  fi
}
################################################################################
JF_create_self_signed_certs() {
  _pwd=$(pwd)
  execCmd "mkdir -pv $HOME/JellyFin/certs" || exit 1
  execCmd "cd $HOME/JellyFin/certs" || exit 1
  cert_dt=$(date +%Y-%m-%dT%H:%M:%S%z)
  execCmd "mkdir $cert_dt" || exit 1
  ## using self signed certificates...
  ## see https://7402.org/blog/2019/new-self-signed-ssl-cert-ios-13.html
  ## Modified for using the openssl built by ccs-calendarserver...
  execCmd "cp /opt/local/etc/openssl/openssl.cnf ${cert_dt}/${_hostname_s}.cnf"
  execCmd "/opt/local/bin/gsed -i\
    -e \"s/^\[\s\s*v3_ca\s\s*\]\s*$/&\nsubjectAltName = DNS:${_hostname_s}.vjpd.net\nextendedKeyUsage = serverAuth\n/\" \
    -e 's/^# \(copy_extensions = copy\)/\1/' \
    ${cert_dt}/${_hostname_s}.cnf \
    " || exit 1
  execCmd "/opt/local/bin/openssl \
    req -x509 -nodes -days 825 -newkey rsa:4096 \
    -config ${cert_dt}/${_hostname_s}.cnf \
    -keyout $cert_dt/jellyfin_server.key.pem \
    -out $cert_dt/jellyfin_server.cert.pem \
    -subj \"/C=DE/ST=By/L=Neubiberg/O=vjpd/CN=peekaboo.vjpd.net\" \
    " || exit 1
  [ -e current ] && execCmd "rm -v current"
  execCmd "ln -s $cert_dt current" || exit 1
  [ ! -e jellyfin_server.cert.pem ] && execCmd "ln -s current/jellyfin_server.cert.pem jellyfin_server.cert.pem" 
  [ ! -e jellyfin_server.key.pem ] && execCmd "ln -s current/jellyfin_server.key.pem jellyfin_server.key.pem" 
  [ ! -e jellyfin_server.chain.pem ] && execCmd "ln -s jellyfin_server.cert.pem jellyfin_server.chain.pem"
  execCmd "/opt/local/bin/openssl \
    pkcs12 -export \
    -out jellyfin.pfx \
    -inkey jellyfin_server.key.pem \
    -in jellyfin_server.cert.pem \
    -passout pass: \
  " || exit 1
  execCmd "cd '${_pwd}'"
}
################################################################################
www_vjpd_net_create_cert_signing_request() {
  _pwd=$(pwd)
  execCmd "mkdir -pv $HOME/www.vjpd.net/certs" || exit 1
  execCmd "cd $HOME/www.vjpd.net/certs" || exit 1
  cert_dt=$(date +%Y-%m-%dT%H:%M:%S%z)
  execCmd "mkdir $cert_dt" || exit 1
  ## using self signed certificates...
  ## see https://7402.org/blog/2019/new-self-signed-ssl-cert-ios-13.html
  ## Modified for using the openssl built by ccs-calendarserver...
if false ; then
  execCmd "cp /opt/local/etc/openssl/openssl.cnf ${cert_dt}/www.vjpd.net.cnf"
  execCmd "/opt/local/bin/gsed -i\
    -e \"s/^\[\s\s*v3_ca\s\s*\]\s*$/&\nsubjectAltName = DNS:www.vjpd.net\nextendedKeyUsage = serverAuth\n/\" \
    -e 's/^# \(copy_extensions = copy\)/\1/' \
    ${cert_dt}/www.vjpd.net.cnf \
    " || exit 1
fi
  execCmd "/opt/local/bin/openssl \
    req -nodes -newkey rsa:4096 \
    -keyout $cert_dt/www.vjpd.net.key.pem \
    -out $cert_dt/www.vjpd.net.csr \
    -subj \"/C=DE/ST=By/L=Neubiberg/O=vjpd/CN=www.vjpd.net\" \
    " || exit 1
if false ; then
  [ -e current ] && execCmd "rm -v current"
  execCmd "ln -s $cert_dt current" || exit 1
  [ ! -e www.vjpd.net.cert.pem ] && execCmd "ln -s current/www.vjpd.net.cert.pem www.vjpd.net.cert.pem" 
  [ ! -e www.vjpd.net.key.pem ] && execCmd "ln -s current/www.vjpd.net.key.pem www.vjpd.net.key.pem" 
  [ ! -e www.vjpd.net.chain.pem ] && execCmd "ln -s www.vjpd.net.cert.pem www.vjpd.net.chain.pem"
  execCmd "/opt/local/bin/openssl \
    pkcs12 -export \
    -out jellyfin.pfx \
    -inkey www.vjpd.net.key.pem \
    -in www.vjpd.net.cert.pem \
    -passout pass: \
  " || exit 1
fi
  execCmd "cd '${_pwd}'"
}
################################################################################
get_mp4tag() {
  mp4info "${1}" | grep ^\ \*"${2}":\  | ${SED} -e "s/^.*${2}: //"
}
################################################################################
setDebug() {
  debug="-D"
}
################################################################################
setVbose() {
  vbose="-v"
}
################################################################################
setQuiet() {
  quiet="-q"
}
################################################################################
setDryRun() {
  debug="-D"
  dryRun="-n"
}
################################################################################
countdown(){
   (( date1=$(${VJPD_FUNCTIONS_DATE} +%s) + $1)); 
   while [[ $date1 -gt $(${VJPD_FUNCTIONS_DATE} +%s) ]]; do 
     echo -ne "$(${VJPD_FUNCTIONS_DATE} -u --date @$(($date1 - $(${VJPD_FUNCTIONS_DATE} +%s))) +%H:%M:%S)\r";
     sleep 0.2
   done
}
################################################################################
dbgCont() {
  [ ! -z "${debug}" ] && read -p "Continue ? " dummy
}
################################################################################
datetime() {
  ${VJPD_FUNCTIONS_DATE} +%Y-%m-%dT%H:%M:%S
}
################################################################################
imageDB_shasum() {
  shasum -a 512 "$1" | awk '{print $1}'
}
################################################################################
imageDB_data_shasum() {
  python -c "from PIL import Image ; import hashlib ; import sys ; print(hashlib.sha512(Image.open(\"${1}\").tobytes()).hexdigest())"
}
################################################################################
imageDB_dtasi_v1() {
  _DT=$(exiftool -T \
    -createdate \
    -datetimeoriginal \
    -modifydate \
    "$1" | gsed -e 's/-//g' -e 's/$/ - -/' | awk '{printf "%s_%s_",$1,$2}' \
  )$(exiftool -T \
    -SubSecTimeOriginal \
    -SubSecTime \
    "$1" | gsed -e 's/-//g' -e 's/$/ -/' | awk '{printf "%s_",$1}' \
  )
  case $(exiftool -T -fileType "$1") in
    JPG|JPEG|HEIC)
      ## -createdate -aperture -shutterspeed -iso link...
      _HDR=$(exiftool -T -CustomRendered "$1" | grep ^HDR >/dev/null && echo _HDR)
      exiftool -T \
        -filenumber \
        -ContentIdentifier \
        -aperture \
        -shutterspeed \
        -iso \
        -ImageSize \
        -GPSTimeStamp \
        -ProfileID \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    PNG)
      ## -createdate -aperture -shutterspeed -iso link...
      exiftool -T \
        -ContentIdentifier \
        -aperture \
        -shutterspeed \
        -iso \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    AVI)
      exiftool -T \
        -videoCodec \
        -videoFrameRate \
        -videoFrameCount \
        -Quality \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    MOV)
      exiftool -T \
        -filenumber \
        -ContentIdentifier \
        -MediaDataSize \
        -MediaDuration \
        -aperture \
        -shutterspeed \
        -iso \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    *)
      exiftool -T \
        -filenumber \
        -aperture \
        -shutterspeed \
        -iso \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
  esac
}
################################################################################
imageDB_dtasi_v2() {
  _DT=$(exiftool -T \
    -createdate \
    -datetimeoriginal \
    "$1" | gsed -e 's/-//g' -e 's/$/ - -/' | awk '{printf "%s_%s_",$1,$2}' \
  )$(exiftool -T \
    -SubSecTimeOriginal \
    -SubSecTime \
    "$1" | gsed -e 's/-//g' -e 's/$/ -/' | awk '{printf "%s_",$1}' \
  )$(exiftool -f -a -S \
    -modifydate \
    "$1" | sort -r | head -n 1 | gsed -e 's/-//g' -e 's/$/ - -/' | awk '{printf "%s_%s_",$2,$3}' \
  )
    #-FileModifyDate \
  case $(exiftool -T -fileType "$1") in
    JPG|JPEG|HEIC)
      ## -createdate -aperture -shutterspeed -iso link...
      _HDR=$(exiftool -T -CustomRendered "$1" | grep ^HDR >/dev/null && echo _HDR)
      exiftool -T \
        -filenumber \
        -ContentIdentifier \
        -aperture \
        -shutterspeed \
        -iso \
        -ImageSize \
        -GPSTimeStamp \
        -ProfileID \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    PNG)
      ## -createdate -aperture -shutterspeed -iso link...
      exiftool -T \
        -ContentIdentifier \
        -aperture \
        -shutterspeed \
        -iso \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    AVI)
      exiftool -T \
        -videoCodec \
        -videoFrameRate \
        -videoFrameCount \
        -Quality \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    MOV)
      exiftool -T \
        -filenumber \
        -ContentIdentifier \
        -MediaDataSize \
        -MediaDuration \
        -aperture \
        -shutterspeed \
        -iso \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    *)
      exiftool -T \
        -filenumber \
        -aperture \
        -shutterspeed \
        -iso \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
  esac
}
################################################################################
imageDB_dtasi() {
  _DT=$(exiftool -m -T \
    -createdate \
    -datetimeoriginal \
    "$1" | gsed -e 's/-//g' -e 's/$/ - -/' | awk '{printf "%s_%s_",$1,$2}' \
  )$(exiftool -m -T \
    -SubSecTimeOriginal \
    -SubSecTime \
    "$1" | gsed -e 's/-//g' -e 's/$/ -/' | awk '{printf "%s_",$1}' \
  )$(exiftool -m -f -a -S \
    -modifydate \
    "$1" | sort -r | head -n 1 | gsed -e 's/-//g' -e 's/$/ - -/' | awk '{printf "%s_%s_",$2,$3}' \
  )
    #-FileModifyDate \
  case $(exiftool -m -T -fileType "$1") in
    JPG|JPEG|HEIC)
      ## -createdate -aperture -shutterspeed -iso link...
      _HDR=$(exiftool -T -CustomRendered "$1" | grep ^HDR >/dev/null && echo _HDR)
      exiftool -m -f -T \
        -filenumber \
        -framenumber \
        -ContentIdentifier \
        -aperture \
        -shutterspeed \
        -iso \
        -ImageSize \
        -GPSTimeStamp \
        -ProfileID \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    PNG)
      ## -createdate -aperture -shutterspeed -iso link...
      exiftool -m -f -T \
        -ContentIdentifier \
        -aperture \
        -shutterspeed \
        -iso \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    AVI)
      exiftool -m -f -T \
        -videoCodec \
        -videoFrameRate \
        -videoFrameCount \
        -Quality \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    MOV|M4V)
      exiftool -m -f -T \
        -filenumber \
        -ContentIdentifier \
        -MediaDataSize \
        -MediaDuration \
        -aperture \
        -shutterspeed \
        -iso \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    MPEG|MPG)
      exiftool -m -f -T \
        -ImageSize \
        -AudioBitrate \
        -SampleRate \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
    *)
      exiftool -m -f -T \
        -filenumber \
        -aperture \
        -shutterspeed \
        -iso \
        -fileTypeExtension \
        "$1" | gsed -e 's/\s\s*/_/g' -e 's[/[:[g' -e "s/$/${_HDR}/" -e "s/^/${_DT}/"
      ;;
  esac
}
#-------------------------------------------------------------------------------
imageDB_shasum_dtasi_links () {
  DBimage="${1}"
  #dryRun="-n"
  #execCmd "chmod a-x \"${DBimage}\""
  shasums_must_be_unique=${shasums_must_be_unique:-false}
  shasum=$(imageDB_shasum "${DBimage}").$(exiftool -T -fileTypeExtension "${DBimage}")
  # AAE file...
  bnfn=$(echo ${DBimage} | gsed -e 's@\(^.*\.\).*@\1@')
  aae_fn=$(ls -1 "${bnfn}"* 2>/dev/null | egrep -i \.aae\$)

  if [ ! -e "${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}" ]; then
    [ ! -d "${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}" ] && execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}\""
    execCmd "ln -f ${quiet:--v} \"${DBimage}\" \"${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}\""
    [ ! -z "${aae_fn}" ] && \
      execCmd "ln -f ${quiet:--v} \"${aae_fn}\" \"${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}.aae\""

    ## dtasi link...
    dtasi=$(imageDB_dtasi "${DBimage}")
    if [ ! -d "${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}" ]; then
      if [ ! -d "${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}" ]; then
        ## This dtasi does not already exist, good...
        execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}\""
        execCmd "ln -f ${quiet:--v} \"${DBimage}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/${shasum}\""
        notQuietLog "'${DBimage}' hardlinked to '${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}'."
      else
        verboseLog "'${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}' already exists"
        if [ ! -e "${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/${shasum}" ]; then
          ## This dtasi already exists but not with this shasum, either:
          ## 1) if relink_dtasis_with_dup_data_shasum=true, relink the current Image
          ##    to the already exisiting shasum
          ## 2) if expunge_dtasis_with_dup_data_shasum=true, expunge the current Image
          ## 3) save/move it to the .dtasi/duplicates dir for later review
          _existsing_dtasi_shasum=$(ls "${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/"* 2>/dev/null | grep -v \$.meta | head -n 1)
          if [ ! -z "${_existsing_dtasi_shasum}" ]; then
            dup_data_shasum_handled=false
            if [ $(imageDB_data_shasum "${DBimage}") == $(imageDB_data_shasum "${_existsing_dtasi_shasum}") ]; then
              dup_data_shasum_handled=true
              if ${relink_dtasis_with_dup_data_shasum:-false} ; then
                notQuietLog "duplicate data_shasums, relinking..."
                execCmd "imageDB_rm_dtasi \"${DBimage}\""
                execCmd "ln -f ${quiet:--v} \"${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}\" \"${DBimage}\""
              elif ${expunge_dtasis_with_dup_data_shasum:-false} ; then
                notQuietLog "duplicate data_shasums, expunging..."
                execCmd "imageDB_expung_dtasi \"${DBimage}\""
                [ ! -z "${aae_fn}" ] && \
                  execCmd "rm -f${vbose:+v} \"${aae_fn}\" \"${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}.aae\""
              else
                dup_data_shasum_handled=false
              fi
            fi
            if ! $dup_data_shasum_handled ; then
              [ ! -d "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" ] && execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/duplicates\""
              execCmd "mv \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}\" \"${SHDB:-${ADDB:-.}}/.dtasi/duplicates\""
            fi
          else
            execCmd "ln -f ${quiet:--v} \"${DBimage}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/${shasum}\""
            notQuietLog "'${DBimage}' hardlinked to '${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}'."
          fi
        else
          if [ ! $(stat -f %i "${DBimage}") == $(stat -f %i "${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}") ]; then
            # Not currently linked so link this image to the shasum...
            execCmd "ln -f ${quiet:--v} \"${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}\" \"${DBimage}\""
            notQuietLog "'${DBimage}' hardlinked to '${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}'."
          fi
        fi
      fi
    fi
    if [ -d "${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}" ]; then
      execCmd "ln -f ${quiet:--v} \"${DBimage}\" \"${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}/${shasum}\""
    fi
  else
    if ${rm_dup_shasums:-false} ; then
      notQuietLog "'${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}' already exists, removing '${DBimage}'..."
      execCmd "rm -f ${vbose:+-v} \"${DBimage}\""
      [ ! -z "${aae_fn}" ] && \
        execCmd "rm -f ${vbose:+-v} \"${aae_fn}\""
      # Don't need to try to rmdir the dir, this can be done later
      # with:
      #  find . -empty -type d -delete -print
    else
      # Is this file already linked to the given shasum link?
      if [ $(stat -f %i "${DBimage}") == $(stat -f %i "${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}") ]; then
        notQuietLog "'${DBimage}' already hardlinked to '${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}'."
      else
        if ${shasums_must_be_unique} ; then
          bnDBimage=$(basename "${DBimage}")
          [ -d "${SHDB:-${ADDB:-.}}/.shasum_already_exists/${bnDBimage}" ] && execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.shasum_already_exists/${bnDBimage}\""
          execCmd "ln -f ${quiet:--v} \"${DBimage}\" \"${SHDB:-${ADDB:-.}}/.shasum_already_exists/${bnDBimage}/${shasum}\""
          [ ! -z "${aae_fn}" ] && \
            execCmd "ln -f ${quiet:--v} \"${aae_fn}\" \"${SHDB:-${ADDB:-.}}/.shasum_already_exists/${bnDBimage}/${shasum}.aae\""
          #errorLog "shasum -a 512 '${DBimage}' = ${shasum} already exists, this should not happen."
          #exit 1
        else
          # Not currently linked so link this image to the shasum...
          execCmd "ln -f ${quiet:--v} \"${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}\" \"${DBimage}\""
          [ ! -z "${aae_fn}" ] && \
            execCmd "ln -f ${quiet:--v} \"${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}.aae\" \"${aae_fn}\""
          notQuietLog "'${DBimage}' hardlinked to '${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}'."
        fi
      fi
    fi
  fi
}
################################################################################
imageDB_rm_dtasi() {
  shasum=$(imageDB_shasum "$1").$(exiftool -T -fileTypeExtension "$1")
  [ -e "${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}" ] && \
    execCmd "rm -fv \"${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}\""
  for dtasi in \
    $(imageDB_dtasi "$1") \
    $(imageDB_dtasi_v2 "${1}") \
    $(imageDB_dtasi_v1 "${1}") \
    ; do
    [ -e "${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/${shasum}" ] && \
      execCmd "\rm -fv \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/${shasum}\"" && \
      execCmd "\rm -fv \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/\".*.meta" && \
      execCmd "\rmdir \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}\""
    [ -e "${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}/${shasum}" ] && \
      execCmd "\rm -fv \"${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}/${shasum}\"" && \
      execCmd "\rm -fv \"${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}/\".*.meta" && \
      execCmd "\rmdir \"${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}\""
    if ${unduplicate_single_file_dtasis:-false} ; then
      if [ -d "${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}" ]; then
        [[ $(ls "${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}" | wc -l) -eq 1 ]] && \
          execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\"" && \
          execCmd "\mv -v \"${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\""
      fi
    fi
  done
  return
  # Messed up dtasi...
  ls "${SHDB:-${ADDB:-.}}/.dtasi/*/*/${shasum}" 2>/dev/null && execCmd "rm -frv \"${SHDB:-${ADDB:-.}}/.dtasi/*/*/${shasum}\""
  # Original filename...
  shasum=$(imageDB_shasum "$1")
  [ -e "${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}" ] && execCmd "rm -fv \"${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}\""
  ls "${SHDB:-${ADDB:-.}}/.dtasi/*/*/${shasum}" 2>/dev/null && execCmd "rm -frv \"${SHDB:-${ADDB:-.}}/.dtasi/*/*/${shasum}\""
}
################################################################################
imageDB_expung_dtasi() {
  _save_SHDB="${SHDB}"
  _k=0
  if ${imageDB_expunge_dtasi_by_samefile:-false} ; then
    shasum=$(find "$SHDB"/.shasum -samefile "${1}")
    shasum=$(basename "${shasum}")
  else
    shasum=${shasum_original:-$(imageDB_shasum "$1")}.$(exiftool -T -fileTypeExtension "${1}")
  fi
  list_dtasi=(\
    $(imageDB_dtasi "${1}") \
    $(imageDB_dtasi_v2 "${1}") \
    $(imageDB_dtasi_v1 "${1}") \
  )
  ## set shasum_original to the shasum of the original file if we don't have the original file anymore...
  debugLog "shasum=${shasum}"
  ## Check for links in the SHDB backup directories...
  for _SHDB in "${SHDB:-${ADDB:-.}}"/.[0-9]* "${_save_SHDB}" ; do
    debugLog "Checking for \"${_SHDB}/.shasum/${shasum:0:3}/${shasum}\""
    if [ -e "${_SHDB}/.shasum/${shasum:0:3}/${shasum}" ]; then
      debugLog "Found \"${_SHDB}/.shasum/${shasum:0:3}/${shasum}\""
      SHDB="${_SHDB}"
      debugLog "SHDB=${SHDB}"
      if [ -z "${shasum_original}" ]; then
        [ -e "${SHDB}/.shasum/${shasum:0:3}/${shasum}" ] && \
          execCmd "rm -fv \"${SHDB}/.shasum/${shasum:0:3}/${shasum}\""
        for dtasi in "${list_dtasi[@]}" ; do
          echo "\"${dtasi}\""
          echo "${SHDB}/.dtasi/${dtasi:0:7}/${dtasi}/${shasum}"
          [ -e "${SHDB}/.dtasi/${dtasi:0:7}/${dtasi}/${shasum}" ] && \
            execCmd "\rm -fv \"${SHDB}/.dtasi/${dtasi:0:7}/${dtasi}/${shasum}\"" && \
            execCmd "\rm -fv \"${SHDB}/.dtasi/${dtasi:0:7}/${dtasi}/\".*.meta" && \
            execCmd "\rmdir \"${SHDB}/.dtasi/${dtasi:0:7}/${dtasi}\""
          echo "${SHDB}/.dtasi/duplicates/${dtasi}/${shasum}"
          [ -e "${SHDB}/.dtasi/duplicates/${dtasi}/${shasum}" ] && \
            execCmd "\rm -fv \"${SHDB}/.dtasi/duplicates/${dtasi}/${shasum}\"" && \
            execCmd "\rm -fv \"${SHDB}/.dtasi/duplicates/${dtasi}/\".*.meta" && \
            execCmd "\rmdir \"${SHDB}/.dtasi/duplicates/${dtasi}\""
          if [ -d "${SHDB}/.dtasi/duplicates/${dtasi}" ] ; then
            dtasi_dir=$(greadlink -f "${SHDB}/.dtasi/duplicates/${dtasi}")
            if [ "${dtasi_dir}" != "${imageDB_expung_dtasi_no_restore}" ]; then
              [[ $(ls "${SHDB}/.dtasi/duplicates/${dtasi}" | wc -l) -eq 1 ]] && \
                execCmd "mkdir -p \"${SHDB}/.dtasi/${dtasi:0:7}\"" && \
                execCmd "\mv -v \"${SHDB}/.dtasi/duplicates/${dtasi}\" \"${SHDB}/.dtasi/${dtasi:0:7}\""
            fi
          fi
        done
      else
        execCmd "rm -fv \"${SHDB}/.shasum/${shasum:0:3}/${shasum}\""
        execCmd "find \"${SHDB}/.dtasi\" -name ${shasum} -exec rm -fv \"{}\" \;"
      fi
    fi
  done
  SHDB="${_save_SHDB}"
}
################################################################################
imageDB_meta() {
  find "${1}" \( \
        -iname \*.heic \
    -o  -iname \*.heiv \
    -o  -iname \*.jpg \
    -o  -iname \*.jpeg \
    -o  -iname \*.jpe \
    -o  -iname \*.png \
    -o  -iname \*.avi \
    -o  -iname \*.mov \
    -o  -iname \*.mpg \
    -o  -iname \*.mpeg \
    -o  -iname \*.mp4 \
    -o  -iname \*.m4v \
    -o  -iname \*.flv \
    -o  -iname \*.tif \
    -o  -iname \*.tiff \
    -o  -iname \*.bmp \
    -o  -iname \*.psd \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
  \) -a -type f | \
    while read file ; do
      _mf=$(dirname "${file}")/.$(basename "${file}").meta
      imageDB_Archive_im "${file}"     >"${_mf}"
      imageDB_ADDB_im "${file}"       >>"${_mf}"
      exiftool -s -a "${file}" | sort >>"${_mf}"
    done
}
################################################################################
imageDB_sdiff_meta() {
  fnames=()
  dir=$(greadlink -f "${1}")
  for F in "${dir}"/* ; do
    fnames[${#fnames[@]}]="${F}"
  done
  _ii=${2:-0}
  (( _iii=_ii+1 ))
  _jj=${3:-${_iii}}
  imageDB_meta "${fnames[${_ii}]}"
  _mf1=$(dirname "${fnames[${_ii}]}")/.$(basename "${fnames[${_ii}]}").meta
  imageDB_meta "${fnames[${_jj}]}"
  _mf2=$(dirname "${fnames[${_jj}]}")/.$(basename "${fnames[${_jj}]}").meta
  sdiff -w $(tput cols) "${_mf1}" "${_mf2}" | less
}
################################################################################
imageDB_SHDB_im() {
  find "${*}" \( \
        -iname \*.heic \
    -o  -iname \*.heiv \
    -o  -iname \*.jpg \
    -o  -iname \*.jpeg \
    -o  -iname \*.jpe \
    -o  -iname \*.png \
    -o  -iname \*.avi \
    -o  -iname \*.mov \
    -o  -iname \*.mpg \
    -o  -iname \*.mpeg \
    -o  -iname \*.mp4 \
    -o  -iname \*.m4v \
    -o  -iname \*.flv \
    -o  -iname \*.tif \
    -o  -iname \*.tiff \
    -o  -iname \*.bmp \
    -o  -iname \*.psd \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
  \) -a -type f | \
    while read file ; do
      verboseLog "\"${file}\""
      find "${SHDB:-.}" -samefile "${file}"
      [ ! -z "${vbose}" ] && imageDB_dtasi "${file}"
      [ ! -z "${vbose}" ] && imageDB_data_shasum "${file}"
    done
}
################################################################################
imageDB_ADDB_im() {
  find "${*}" \( \
        -iname \*.heic \
    -o  -iname \*.heiv \
    -o  -iname \*.jpg \
    -o  -iname \*.jpeg \
    -o  -iname \*.jpe \
    -o  -iname \*.png \
    -o  -iname \*.avi \
    -o  -iname \*.mov \
    -o  -iname \*.mpg \
    -o  -iname \*.mpeg \
    -o  -iname \*.mp4 \
    -o  -iname \*.m4v \
    -o  -iname \*.flv \
    -o  -iname \*.tif \
    -o  -iname \*.tiff \
    -o  -iname \*.bmp \
    -o  -iname \*.psd \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
  \) -a -type f | \
    while read file ; do
      verboseLog "\"${file}\""
      find "${ADDB:-.}" -depth 1 -samefile "${file}"
      [ ! -z "${vbose}" ] && imageDB_dtasi "${file}"
      [ ! -z "${vbose}" ] && imageDB_data_shasum "${file}"
    done
}
################################################################################
imageDB_Archive_im() {
  AD=$(dirname "${ADDB:-.}")
  find "${*}" \( \
        -iname \*.heic \
    -o  -iname \*.heiv \
    -o  -iname \*.jpg \
    -o  -iname \*.jpeg \
    -o  -iname \*.jpe \
    -o  -iname \*.png \
    -o  -iname \*.avi \
    -o  -iname \*.mov \
    -o  -iname \*.mpg \
    -o  -iname \*.mpeg \
    -o  -iname \*.mp4 \
    -o  -iname \*.m4v \
    -o  -iname \*.flv \
    -o  -iname \*.tif \
    -o  -iname \*.tiff \
    -o  -iname \*.bmp \
    -o  -iname \*.psd \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
  \) -a -type f | \
    while read file ; do
      verboseLog "\"${file}\""
      find "${AD}"/{FaceBook,Incoming,Movies,Not\ for\ Public,Our\ Pictures,Panoramas,Scans,Technical\ Pictures,WWW\ Pictures} \
        -samefile "${file}"
      [ ! -z "${vbose}" ] && imageDB_dtasi "${file}"
      [ ! -z "${vbose}" ] && imageDB_data_shasum "${file}"
    done
}
################################################################################
imageDB_shasums_of_ADDB_im() {
  _save_vbose=${vbose}
  unset vbose
  find "${*}" \( \
      -iname \*.heic \
    -o  -iname \*.heiv \
    -o  -iname \*.jpg \
    -o  -iname \*.jpeg \
    -o  -iname \*.jpe \
    -o  -iname \*.png \
    -o  -iname \*.avi \
    -o  -iname \*.mov \
    -o  -iname \*.mpg \
    -o  -iname \*.mpeg \
    -o  -iname \*.mp4 \
    -o  -iname \*.m4v \
    -o  -iname \*.flv \
    -o  -iname \*.tif \
    -o  -iname \*.tiff \
    -o  -iname \*.bmp \
    -o  -iname \*.psd \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
  \) -a -type f | \
    while read file ; do
      _n_ADDB_ims=$(imageDB_ADDB_im "${file}" | wc -l)
      [[ ${_n_ADDB_ims:-0} -ne 0 ]] && echo "${file}"
    done
  reset_vbose
}
################################################################################
imageDB_shasums_of_Archive_im() {
  _save_vbose=${vbose}
  unset vbose
  find "${1}" \( \
         -iname \*.heic \
    -o  -iname \*.heiv \
    -o  -iname \*.jpg \
    -o  -iname \*.jpeg \
    -o  -iname \*.jpe \
    -o  -iname \*.png \
    -o  -iname \*.avi \
    -o  -iname \*.mov \
    -o  -iname \*.mpg \
    -o  -iname \*.mpeg \
    -o  -iname \*.mp4 \
    -o  -iname \*.m4v \
    -o  -iname \*.flv \
    -o  -iname \*.tif \
    -o  -iname \*.tiff \
    -o  -iname \*.bmp \
    -o  -iname \*.psd \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
  \) -a -type f | \
    while read file ; do
      _n_Archive_ims=$(imageDB_Archive_im "${file}" | grep ${3} "${2}" | wc -l)
      [[ ${_n_Archive_ims:-0} -ne 0 ]] && echo "${file}"
    done
  reset_vbose
}
################################################################################
imageDB_shasums_of_Archive_im_AC() {
  imageDB_shasums_of_Archive_im "${1}" "Family/Alexis&Camille"
}
################################################################################
imageDB_shasums_of_Archive_im_MP() {
  imageDB_shasums_of_Archive_im "${1}" "Family/Mamie&Papi"
}
################################################################################
imageDB_shasums_of_Archive_im_nMP() {
  imageDB_shasums_of_Archive_im "${1}" "Family/Mamie&Papi" "-v"
}
################################################################################
imageDB_relink_Archive_ims() {
  # <im_original> <im_new>
  # This is usually used when one modifies a version of the file and then wants
  # to relink all the other versions of the same file that were linked to the original
  # to the new version (e.g. after fixing the datetimeoriginal)
  AD=$(dirname "${ADDB}")
  im_original="${1}"
  im_new="${2}"
  _save_SHDB="${SHDB}"
  _a_SHDB=()
  ## set shasum_original to the shasum of the original file if we don't have the original file anymore...
  shasum=${shasum_original:-$(imageDB_shasum "$im_original")}.$(exiftool -T -fileTypeExtension "${im_original}")
  debugLog "shasum=${shasum}"
  ## Check for links in the SHDB backup and SHDB directories...
  for _SHDB in "${SHDB:-${ADDB:-.}}"/.[0-9]* "${_save_SHDB}" ; do
    debugLog "Checking for \"${_SHDB}/.shasum/${shasum:0:3}/${shasum}\""
    if [ -e "${_SHDB}/.shasum/${shasum:0:3}/${shasum}" ]; then
      debugLog "Found \"${_SHDB}/.shasum/${shasum:0:3}/${shasum}\""
      SHDB="${_SHDB}"
      debugLog "SHDB=${SHDB}"
      if [ -z "${shasum_original}" ]; then
        execCmd "imageDB_rm_dtasi \"$im_original\""
      else
        execCmd "rm -fv \"${SHDB}/.shasum/${shasum:0:3}/${shasum}\""
        execCmd "find \"${SHDB}/.dtasi\" -name ${shasum} -exec rm -fv \"{}\" \;"
      fi
      [ "${_SHDB}" != "${_save_SHDB}" ] && _a_SHDB[${#_a_SHDB[@]}]="${_SHDB}"
    fi
  done
  SHDB="${_save_SHDB}"
  execCmd "find \"${AD}\" \
      -samefile \"${im_original}\" \
      -exec ln -f ${quiet:--v} \"${im_new}\" \"{}\" \;"
  execCmd "imageDB_shasum_dtasi_links \"$im_new\""

  for SHDB in "${_a_SHDB[@]}" ; do
    debugLog "SHDB=${SHDB:-${ADDB:-.}}"
    execCmd "imageDB_shasum_dtasi_links \"$im_new\""
  done
  SHDB="${_save_SHDB}"
  unset _save_SHDB
  unset _a_SHDB
}
################################################################################
imageDB_rm_from_Archive() {
  AD=$(dirname "${ADDB}")
  find "${AD}"/{Movies,Not\ for\ Public,Our\ Pictures,Panoramas,Scans,Technical\ Pictures} \
    -samefile "${1}" \
    -exec rm -v "{}" \;
}
################################################################################
imageDB_expung_from_Archive() {
  AD=$(dirname "${ADDB}")
  find "${AD}" \
    -samefile "${1}" \
    -exec rm -v "{}" \;
  echo "Remember, if this image comes from an iPhone/iPad, it needs to be removed"
  echo "in the source laptop, otherwise it will be re-added the next time the laptop"
  echo "is synced."
}
################################################################################
imageDB_keep_remaining_dup_dtasis() {
  dtasi=$(basename "${1}")
  echo "Keeping remaining dups for dtasi='${dtasi}' and linking in same_data_checksum..."
  execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\""
  execCmd "mv -v \"${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\""
  execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
  execCmd "ln -f ${vbose:+-v} \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/\"* \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
}
################################################################################
imageDB_keep_remaining_dup_dtasis_all_unique_shasums() {
  dtasi=$(basename "${1}")
  echo "Keeping remaining dups for dtasi='${dtasi}' and linking in all_unique_data_checksum..."
  execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\""
  execCmd "mv -v \"${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\""
  execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/all_unique_data_checksum/${dtasi:0:7}/${dtasi}\""
  execCmd "ln -f ${vbose:+-v} \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/\"* \"${SHDB:-${ADDB:-.}}/.dtasi/all_unique_data_checksum/${dtasi:0:7}/${dtasi}\""
}
################################################################################
imageDB_D40_correct_datetimeoriginal() {
  # Correct the datetimeoriginal key in the 

  # Reset datetimeoriginal back to createdate with...
  # exiftool  -datetimeoriginal\<createdate <file>
  notQuietLog "Checking '${1}'..."
  if [ -e "${1}_original" ]; then
    errorLog "'${1}_original' already exists."
    return 1
  else
    execCmd "exiftool ${vbose:--q} \
      -datetimeoriginal+='0:8:8 15:10:00' \
      -if '\
        \$model eq \"Canon EOS 40D\" \
        and \
        \$datetimeoriginal eq \$createdate \
        and \
        \$createdate lt \"2011:02:23 15:34:44\" \
      ' \
      \"${1}\" \
    "
    if [ -e "${1}_original" ]; then
      notQuietLog "---------------------------------------------------------------------------"
      notQuietLog "'${1}' :: Fixing dateTimeOriginal."
      execCmd "imageDB_relink_Archive_ims \"${1}_original\" \"${1}\""
      execCmd "rm -f${vbose:+v} \"${1}_original\""
    fi
  fi
}
################################################################################
imageDB_D40_reset_then_correct_datetimeoriginal() {
  execCmd "exiftool  -datetimeoriginal\<createdate \"${1}\""
  if [ $? == 0 ]; then
    execCmd "rm -f \"${1}\"_original"
    imageDB_D40_correct_datetimeoriginal "${1}"
  fi
}
################################################################################
imageDB_retry_dup() {
  echo "======================================"
  echo "$1"
  rm -f "$1"/*.meta 2>/dev/null
  ls -1 "$1"
  mv "$1" tmp
  for F in tmp/"$1"/* ; do
    oF=$(find "${ADDB:-.}" -depth 1 -samefile $F)
    if [ ! -z "${oF}" ]; then
      imageDB_rm_dtasi "${oF}"
      ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.imageDB_relink_duplicates \
        --ADDB "${ADDB:-.}" \
        -i "${oF}"
    fi
  done
  rm -fr tmp/$D
}
################################################################################
reset_vbose() {
  if [ ! -z "${_save_vbose}" ]; then
    vbose="${_save_vbose}"
    unset _save_vbose
  fi
}
################################################################################
imageDB_check_for_identical_data_shasums() {
  ## check the files in a .dtasi_duplicates directory for identical data_shasums
  unset _refDS
  _a_refDS=()
  _sameDS=true
  _n_ims=0
  _save_vbose=${vbose}
  unset vbose
  truncated_images=()
  _nti=0
  _ndds=1
  ok_images=()
  _oki=0
  [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
  [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
  execCmd "mkdir -p${vbose:+v} \"${1}/.unique_data_shasums\""
  for F in $(ls "${1}" | grep -v \.meta\$) ; do
    file=${1}/${F}
    _n_ADDB_ims=$(imageDB_ADDB_im "${file}" | wc -l)
    _n_Archive_ims=$(imageDB_Archive_im "${file}" | wc -l)
    if ${imageDB_rm_zero_linked_shasums:-false} && \
      [[ ${_n_ADDB_ims:-1} -eq 0 ]] && \
      [[ ${_n_Archive_ims:-1} -eq 0 ]] && \
      true ; then
      echo "\"${file}\" has no links, imageDB_rm_zero_linked_shasums=true --> removing..."
      imageDB_expung_dtasi_no_restore=$(greadlink -f "${1}")
      execCmd "imageDB_expung_dtasi \"${file}\""
      unset imageDB_expung_dtasi_no_restore
    else
      # Check for TRUNCATED images...
      (( _n_ims++ ))
      _DS=$(imageDB_data_shasum "${file}")
      if [[ $? -eq 0 ]]; then
        have_this_DS_already=false
        if [ ! -d "${1}/.unique_data_shasums/${_DS}" ]; then
          execCmd "mkdir -p${vbose:+v} \"${1}/.unique_data_shasums/${_DS}\""
          execCmd "ln -f${vbose:+v} \"${file}\" \"${1}/.unique_data_shasums/${_DS}/\""
        else
          execCmd "mkdir -p${vbose:+v} \"${1}/.duplicate_data_shasums\""
          execCmd "mv ${vbose} \"${1}/.unique_data_shasums/${_DS}\" \"${1}/.duplicate_data_shasums\""
          execCmd "ln -f${vbose:+v} \"${file}\" \"${1}/.duplicate_data_shasums/${_DS}/\""
          have_this_DS_already=true
        fi
        ! ${have_this_DS_already} && _a_refDS[${#_a_refDS[@]}]=${_DS:--1}
        [ -z "${_refDS}" ] && _refDS=${_DS:--1}
        if [ ${_DS:--1} != $_refDS ]; then
          _sameDS=false
          (( _ndds++ ))
        fi
        ok_images[$_oki]="${file}"
        (( _oki++ ))
      else
        _sameDS=false
        truncated_images[$_nti]="${file}"
        (( _nti++ ))
      fi
    fi
  done
  if [[ $_oki -eq 1 ]] && [[ $_nti -ge 1 ]]; then
    echo "\"${1}\" : One or more truncated images and one OK, relinking the truncated version(s) to the OK version..."
    [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
    [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
    _dn=$(dirname "${1}")
    _bn=$(basename "${1}")
    fix_dir=${_dn}/fix_${_bn}
    mv "${1}" "${fix_dir}"
    im_ADDB="${fix_dir}/$(basename ${ok_images[0]})"
    find "${fix_dir}" \( \
           -iname \*.heic \
      -o  -iname \*.heiv \
      -o  -iname \*.jpg \
      -o  -iname \*.jpeg \
      -o  -iname \*.jpe \
      -o  -iname \*.png \
      -o  -iname \*.avi \
      -o  -iname \*.mov \
      -o  -iname \*.mpg \
      -o  -iname \*.mpeg \
      -o  -iname \*.mp4 \
      -o  -iname \*.m4v \
      -o  -iname \*.flv \
      -o  -iname \*.tif \
      -o  -iname \*.tiff \
      -o  -iname \*.bmp \
      -o  -iname \*.psd \
      -o  -iname \*.cr2 \
      -o  -iname \*.dng \
      -o  -iname \*.gif \
      -o  -iname \*.cr2 \
      -o  -iname \*.dng \
      -o  -iname \*.gif \
    \) -a -type f | \
      while read file ; do
        if [ "$file" != "${im_ADDB}" ]; then
          execCmd "imageDB_rm_dtasi \"${file}\""
          execCmd "imageDB_relink_Archive_ims \"${file}\" \"${im_ADDB}\""
        fi
      done
    execCmd "rm -fr -v \"${fix_dir}\""
    reset_vbose
    return
  elif [[ $_oki -gt 1 ]] && [[ $_nti -ge 1 ]]; then
    [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
    [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
    echo "\"${1}\" : One or more truncated images and more than OK, not sure what to do..."
    reset_vbose
    return
  fi

  #
  if [[ ${_n_ims} -eq 0 ]]; then
    # it seems all images were removed and this dir no longer exists...
    echo "\"${1}\" : NO images left, removing this directory..."
    reset_vbose
    return
  fi
  # 
  if [[ ${_n_ims} -eq 1 ]]; then
    # it seems all but one images were removed so this dir can be removed from duplicates...
    [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
    [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
    echo "\"${1}\" : ONE image left, restoring this directory to .dtasi..."
    dtasi=$(basename "${1}")
    if [ -d "${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}" ]; then
      [[ $(ls "${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}" | wc -l) -eq 1 ]] && \
        execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\"" && \
        execCmd "\mv -v \"${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\""
    fi
    reset_vbose
    return
  fi

  ## No truncated images, check now for duplicate data-shasums...
  if ${_sameDS} ; then
    [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
    [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
    all_n="all ${_n_ims}"
    [[ ${_n_ims} -eq 2 ]] && all_n="both"
    echo "\"${1}\" : ${all_n} images have the same data-shasums"
    _n_ADDB_ims=$(imageDB_ADDB_im "${1}" | wc -l)
    _n_Archive_ims=$(imageDB_Archive_im "${1}" | wc -l)
    _n_Archive_ims_MP=$(imageDB_Archive_im "${1}" | grep 'Family/Mamie&Papi' | wc -l)
    _n_Archive_ims_AC=$(imageDB_Archive_im "${1}" | grep 'Family/Alexis&Camille' | wc -l)
    _n_Archive_ims_DSS=$(imageDB_Archive_im "${1}" | grep 'Nana&GrandDad/Dads slide show' | wc -l)
    _n_Archive_ims_nMP=$(imageDB_Archive_im "${1}" | grep -v 'Family/Mamie&Papi' | wc -l)
    if [[ ${_n_ims} -eq 2 ]]; then
      if [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 1 ]] && \
        [[ ${_n_Archive_ims} -eq 1 ]] && \
        true ; then
        dtasi=$(basename "${1}")
        echo "One image each in Archive and ADDB, assuming Archive version meta-data has been modified deliberately, keeping and linking in same_data_checksum..."
        execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\""
        execCmd "mv -v \"${1}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/\""
        execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
        execCmd "ln -f ${_save_vbose:+-v} \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/\"* \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
      fi
      if [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 1 ]] && \
        [[ ${_n_Archive_ims_nMP} -eq 1 ]] && \
        [[ ${_n_Archive_ims} -ge 2 ]] && \
        [[ ${_n_Archive_ims_MP} -ge 1 ]] && \
        true ; then
        im_MP=$(imageDB_Archive_im "${1}" | grep 'Family/Mamie&Papi' | head -n 1)
        im_nMP=$(imageDB_Archive_im "${1}" | grep -v 'Family/Mamie&Papi')
        _n_ADDB_im_nMP=$(imageDB_ADDB_im "${im_nMP}" | wc -l)
        if [ ${_n_ADDB_im_nMP} == 1 ]; then
          echo "One image not-in-Mamie&Papi=ADDB and one or more in Mamie&Papa, relinking the Mamie&Papi versions to the not-in-Mamie&Papi=ADDB version..."
          find "${1}" \( \
                 -iname \*.heic \
            -o  -iname \*.heiv \
            -o  -iname \*.jpg \
            -o  -iname \*.jpeg \
            -o  -iname \*.jpe \
            -o  -iname \*.png \
            -o  -iname \*.avi \
            -o  -iname \*.mov \
            -o  -iname \*.mpg \
            -o  -iname \*.mpeg \
            -o  -iname \*.mp4 \
            -o  -iname \*.m4v \
            -o  -iname \*.flv \
            -o  -iname \*.tif \
            -o  -iname \*.tiff \
            -o  -iname \*.bmp \
            -o  -iname \*.psd \
            -o  -iname \*.cr2 \
            -o  -iname \*.dng \
            -o  -iname \*.gif \
            -o  -iname \*.cr2 \
            -o  -iname \*.dng \
            -o  -iname \*.gif \
          \) -a -type f | \
            while read file ; do
              execCmd "imageDB_rm_dtasi \"${file}\""
            done
          execCmd "rm -fr -v \"${1}\""
          execCmd "imageDB_relink_Archive_ims \"${im_MP}\" \"${im_nMP}\""
        fi
      fi
      if [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 0 ]] && \
        [[ ${_n_Archive_ims_nMP} -eq 1 ]] && \
        [[ ${_n_Archive_ims} -ge 2 ]] && \
        [[ ${_n_Archive_ims_MP} -ge 1 ]] && \
        true ; then
        echo "One image not-in-Mamie&Papi, one or more in Mamie&Papa and none in ADDB, relinking the Mamie&Papi versions to the not-in-Mamie&Papi version..."
        _dn=$(dirname "${1}")
        _bn=$(basename "${1}")
        fix_dir=${_dn}/fix_${_bn}
        mv "${1}" "${fix_dir}"
        im_ADDB=$(imageDB_shasums_of_Archive_im_nMP "${fix_dir}")
        find "${fix_dir}" \( \
               -iname \*.heic \
          -o  -iname \*.heiv \
          -o  -iname \*.jpg \
          -o  -iname \*.jpeg \
          -o  -iname \*.jpe \
          -o  -iname \*.png \
          -o  -iname \*.avi \
          -o  -iname \*.mov \
          -o  -iname \*.mpg \
          -o  -iname \*.mpeg \
          -o  -iname \*.mp4 \
          -o  -iname \*.m4v \
          -o  -iname \*.flv \
          -o  -iname \*.tif \
          -o  -iname \*.tiff \
          -o  -iname \*.bmp \
          -o  -iname \*.psd \
          -o  -iname \*.cr2 \
          -o  -iname \*.dng \
          -o  -iname \*.gif \
          -o  -iname \*.cr2 \
          -o  -iname \*.dng \
          -o  -iname \*.gif \
        \) -a -type f | \
          while read file ; do
            if [ "$file" != "${im_ADDB}" ]; then
              execCmd "imageDB_rm_dtasi \"${file}\""
              execCmd "imageDB_relink_Archive_ims \"${file}\" \"${im_ADDB}\""
            fi
          done
        execCmd "rm -fr -v \"${fix_dir}\""
        [ ! -z "${dryRun}" ] && mv "${fix_dir}" "${1}"
      fi
      if [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 1 ]] && \
        [[ ${_n_Archive_ims} -ge 2 ]] && \
        [[ ${_n_Archive_ims_nMP} -eq 0 ]] && \
        [[ ${_n_Archive_ims_MP} -ge 2 ]] && \
        true ; then
        echo "One image in Mamie&Papi=ADDB and one or more others in Mamie&Papa, relinking all the Mamie&Papi versions to the Mamie&Papi=ADDB version..."
        _dn=$(dirname "${1}")
        _bn=$(basename "${1}")
        fix_dir=${_dn}/fix_${_bn}
        mv "${1}" "${fix_dir}"
        im_ADDB=$(imageDB_shasums_of_ADDB_im "${fix_dir}")
        find "${fix_dir}" \( \
               -iname \*.heic \
          -o  -iname \*.heiv \
          -o  -iname \*.jpg \
          -o  -iname \*.jpeg \
          -o  -iname \*.jpe \
          -o  -iname \*.png \
          -o  -iname \*.avi \
          -o  -iname \*.mov \
          -o  -iname \*.mpg \
          -o  -iname \*.mpeg \
          -o  -iname \*.mp4 \
          -o  -iname \*.m4v \
          -o  -iname \*.flv \
          -o  -iname \*.tif \
          -o  -iname \*.tiff \
          -o  -iname \*.bmp \
          -o  -iname \*.psd \
          -o  -iname \*.cr2 \
          -o  -iname \*.dng \
          -o  -iname \*.gif \
        \) -a -type f | \
          while read file ; do
            if [ "$file" != "${im_ADDB}" ]; then
              execCmd "imageDB_rm_dtasi \"${file}\""
              execCmd "imageDB_relink_Archive_ims \"${file}\" \"${im_ADDB}\""
            fi
          done
        execCmd "rm -fr -v \"${fix_dir}\""
        [ ! -z "${dryRun}" ] && mv "${fix_dir}" "${1}"
      fi
      if [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 0 ]] && \
        [[ ${_n_Archive_ims_nMP} -ge 1 ]] && \
        [[ ${_n_Archive_ims} -ge 2 ]] && \
        [[ ${_n_Archive_ims_MP} -ge 1 ]] && \
        [[ ${_n_Archive_ims_AC} -ge 1 ]] && \
        true ; then
        # Messed up directories that need to be re-synced from Jarvis...
        # /Volumes/LaCie Disk/Archive/imageDB/Our Pictures/Family/Alexis&Camille/Le Marriage/En Avance
        # /Volumes/LaCie Disk/Archive/imageDB/Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/Mariage de Alexis et Camille/Le Jour Avant
        #
        # /Volumes/LaCie Disk/Archive/imageDB/Our Pictures/Family/Alexis&Camille/Le Marriage/Le Jour Apres
        # /Volumes/LaCie Disk/Archive/imageDB/Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/Mariage de Alexis et Camille/Le Jour Apres
        #
        # /Volumes/LaCie Disk/Archive/imageDB/Our Pictures/Family/Alexis&Camille/ca.doublier/Mathilde été 2007
        # /Volumes/LaCie Disk/Archive/imageDB/Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes Images_2/Mathilde/Mathilde_finJuin_miJuil2007
        echo "One image Mamie&Papi and one in Alexis&Camille, relinking the Mamie&Papi version to the Alexis&Camille version..."
        _dn=$(dirname "${1}")
        _bn=$(basename "${1}")
        fix_dir=${_dn}/fix_${_bn}
        mv "${1}" "${fix_dir}"
        im_ADDB=$(imageDB_shasums_of_Archive_im_AC "${fix_dir}")
        find "${fix_dir}" \( \
               -iname \*.heic \
          -o  -iname \*.heiv \
          -o  -iname \*.jpg \
          -o  -iname \*.jpeg \
          -o  -iname \*.jpe \
          -o  -iname \*.png \
          -o  -iname \*.avi \
          -o  -iname \*.mov \
          -o  -iname \*.mpg \
          -o  -iname \*.mpeg \
          -o  -iname \*.mp4 \
          -o  -iname \*.m4v \
          -o  -iname \*.flv \
          -o  -iname \*.tif \
          -o  -iname \*.tiff \
          -o  -iname \*.bmp \
          -o  -iname \*.psd \
          -o  -iname \*.cr2 \
          -o  -iname \*.dng \
          -o  -iname \*.gif \
        \) -a -type f | \
          while read file ; do
            if [ "$file" != "${im_ADDB}" ]; then
                execCmd "imageDB_rm_dtasi \"${file}\""
                execCmd "imageDB_relink_Archive_ims \"${file}\" \"${im_ADDB}\""
            fi
          done
        execCmd "rm -fr -v \"${fix_dir}\""
        [ ! -z "${dryRun}" ] && mv "${fix_dir}" "${1}"
      fi
      if [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 1 ]] && \
        [[ ${_n_Archive_ims} -ge 2 ]] && \
        [[ ${_n_Archive_ims_DSS} -ge 1 ]] && \
        true ; then
        im_ADDB=$(imageDB_shasums_of_ADDB_im "${1}")
        im_nDSS=$(imageDB_shasums_of_Archive_im "${1}" "Nana&GrandDad/Dads slide show" "-v")
        if [ "${im_ADDB:-0}" == "${im_nDSS:-1}" ]; then
          echo "One image 'Nana&GrandDad/Dads slide show' and one not=ADDB, relinking the 'Nana&GrandDad/Dads slide show' version to the not=ADDB version..."
          _dn=$(dirname "${1}")
          _bn=$(basename "${1}")
          fix_dir=${_dn}/fix_${_bn}
          mv "${1}" "${fix_dir}"
          im_ADDB=${fix_dir}/$(basename "${im_ADDB}")
          find "${fix_dir}" \( \
                 -iname \*.heic \
            -o  -iname \*.heiv \
            -o  -iname \*.jpg \
            -o  -iname \*.jpeg \
            -o  -iname \*.jpe \
            -o  -iname \*.png \
            -o  -iname \*.avi \
            -o  -iname \*.mov \
            -o  -iname \*.mpg \
            -o  -iname \*.mpeg \
            -o  -iname \*.mp4 \
            -o  -iname \*.m4v \
            -o  -iname \*.flv \
            -o  -iname \*.tif \
            -o  -iname \*.tiff \
            -o  -iname \*.bmp \
            -o  -iname \*.psd \
            -o  -iname \*.cr2 \
            -o  -iname \*.dng \
            -o  -iname \*.gif \
          \) -a -type f | \
            while read file ; do
              if [ "$file" != "${im_ADDB}" ]; then
                execCmd "imageDB_rm_dtasi \"${file}\""
                execCmd "imageDB_relink_Archive_ims \"${file}\" \"${im_ADDB}\""
              fi
            done
          execCmd "rm -fr -v \"${fix_dir}\""
          [ ! -z "${dryRun}" ] && mv "${fix_dir}" "${1}"
        else
          echo "One image 'Nana&GrandDad/Dads slide show' and one not=/=ADDB, not relinking..."
        fi
      fi
      if [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 0 ]] && \
        true ; then
        im_KKCD7=$(imageDB_shasums_of_Archive_im "${1}" "KinderKrippe Hippos/CD7")
        im_KKCD8=$(imageDB_shasums_of_Archive_im "${1}" "KinderKrippe Hippos/CD8")
        if [ ! -z "${im_KKCD7}" ] && [ ! -z "${im_KKCD8}" ]; then
          echo "One image in 'KinderKrippe Hippos/CD7' and one in 'KinderKrippe Hippos/CD8', expunging the one in 'KinderKrippe Hippos/CD8'..."
          execCmd "imageDB_expung_from_Archive \"${im_KKCD8}\""
          execCmd "imageDB_expung_dtasi \"${im_KKCD8}\""
        fi
      fi
    fi
    if [[ ${_n_ims} -gt 2 ]]; then
      echo "${_n_ADDB_ims} ${_n_Archive_ims_nMP} ${_n_Archive_ims} ${_n_Archive_ims_MP}"
      if [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 1 ]] && \
        [[ ${_n_Archive_ims_nMP} -eq 1 ]] && \
        [[ ${_n_Archive_ims} -ge 2 ]] && \
        [[ ${_n_Archive_ims_MP} -ge 1 ]] && \
        true ; then
        dtasi=$(basename "${1}")
        im_MP=$(imageDB_Archive_im "${1}" | grep 'Family/Mamie&Papi' | head -n 1)
        im_nMP=$(imageDB_Archive_im "${1}" | grep -v 'Family/Mamie&Papi')
        im_ADDB=$(imageDB_ADDB_im "${1}")
        _n_ADDB_im_nMP=$(imageDB_ADDB_im "${im_nMP}" | wc -l)
        echo "One image not-in-Mamie&Papi and one or more in Mamie&Papa, relinking the Mamie&Papi versions to the not-in-Mamie&Papi version..."
        find "${1}" \( \
              -iname \*.heic \
          -o  -iname \*.heiv \
          -o  -iname \*.jpg \
          -o  -iname \*.jpeg \
          -o  -iname \*.jpe \
          -o  -iname \*.png \
          -o  -iname \*.avi \
          -o  -iname \*.mov \
          -o  -iname \*.mpg \
          -o  -iname \*.mpeg \
          -o  -iname \*.mp4 \
          -o  -iname \*.m4v \
          -o  -iname \*.flv \
          -o  -iname \*.tif \
          -o  -iname \*.tiff \
          -o  -iname \*.bmp \
          -o  -iname \*.psd \
          -o  -iname \*.cr2 \
          -o  -iname \*.dng \
          -o  -iname \*.gif \
        \) -a -type f | \
          while read file ; do
            execCmd "imageDB_rm_dtasi \"${file}\""
          done
        for im_MP in $(imageDB_shasums_of_Archive_im_MP \"${1}\") ; do
          execCmd "imageDB_relink_Archive_ims \"${im_MP}\" \"${im_nMP}\""
          execCmd "rm \"${im_MP}\""
        done
        if [ "${im_ADDB}" != "${im_nMP}"]; then
          echo "ADDB version =/= not-in-Mamie&Papi, keeping and linking in same_data_checksum..."
          execCmd "mv -v \"${im_ADDB}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/\""
          execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
          execCmd "ln -f ${_save_vbose:+-v} \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/\"* \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
        fi
        execCmd "rm -fr -v \"${1}\""
      fi
    fi
    if [ -d "${1}" ] && \
      [[ ${_n_ADDB_ims} -eq 0 ]] && \
      [[ ${_n_Archive_ims_nMP} -eq 0 ]] && \
      [[ ${_n_Archive_ims} -ge 2 ]] && \
      [[ ${_n_Archive_ims_MP} -ge 2 ]] && \
      true ; then
      echo "One or more images Mamie&Papi and no ADDB, relinking all the Mamie&Papi versions to the latest fileModifyDate version..."
      _dn=$(dirname "${1}")
      _bn=$(basename "${1}")
      fix_dir=${_dn}/fix_${_bn}
      mv "${1}" "${fix_dir}"
      im_ADDB="${fix_dir}"/$(exiftool -d %s -T -a \
        -filemodifydate -filename \
        "${fix_dir}" | \
        sort -nk 1 | \
        head -n 1 | \
        awk '{printf "%s",$2}' \
        )
      find "${fix_dir}" \( \
            -iname \*.heic \
        -o  -iname \*.heiv \
        -o  -iname \*.jpg \
        -o  -iname \*.jpeg \
        -o  -iname \*.jpe \
        -o  -iname \*.png \
        -o  -iname \*.avi \
        -o  -iname \*.mov \
        -o  -iname \*.mpg \
        -o  -iname \*.mpeg \
        -o  -iname \*.mp4 \
        -o  -iname \*.m4v \
        -o  -iname \*.flv \
        -o  -iname \*.tif \
        -o  -iname \*.tiff \
        -o  -iname \*.bmp \
        -o  -iname \*.psd \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
      \) -a -type f | \
        while read file ; do
          if [ "$file" != "${im_ADDB}" ]; then
            execCmd "imageDB_rm_dtasi \"${file}\""
            execCmd "imageDB_relink_Archive_ims \"${file}\" \"${im_ADDB}\""
          fi
        done
      execCmd "rm -fr -v \"${fix_dir}\""
    fi
  else
    if [[ ${_n_ims} -eq 2 ]]; then
      _n_ADDB_ims=$(imageDB_ADDB_im "${1}" | wc -l)
      _n_Archive_ims=$(imageDB_Archive_im "${1}" | wc -l)
      _n_Archive_ims_MP=$(imageDB_Archive_im "${1}" | grep 'Family/Mamie&Papi' | wc -l)
      _n_Archive_ims_MP_ov=$(imageDB_Archive_im "${1}" | grep 'Family/Mamie&Papi/Old versions' | wc -l)
      _n_Archive_ims_MP_dlmd=$(imageDB_Archive_im "${1}" | grep 'Family/Mamie&Papi/Downloaded Albums/michel.doublier' | wc -l)
      _n_Archive_ims_MP_dldm=$(imageDB_Archive_im "${1}" | grep 'Family/Mamie&Papi/Downloaded Albums/doublierMD' | wc -l)
      _n_Archive_ims_AC=$(imageDB_Archive_im "${1}" | grep 'Family/Alexis&Camille' | wc -l)
      _n_Archive_ims_AC_cad=$(imageDB_Archive_im "${1}" | grep 'Family/Alexis&Camille/ca.doublier' | wc -l)
      _n_Archive_ims_DSS=$(imageDB_Archive_im "${1}" | grep 'Nana&GrandDad/Dads slide show' | wc -l)
      _n_Archive_ims_nMP=$(imageDB_Archive_im "${1}" | grep -v 'Family/Mamie&Papi' | wc -l)
      im_KKCD7=$(imageDB_shasums_of_Archive_im "${1}" "KinderKrippe Hippos/CD7")
      im_KKCD8=$(imageDB_shasums_of_Archive_im "${1}" "KinderKrippe Hippos/CD8")
      [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
      [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
      if [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 1 ]] && \
        ${imageDB_relink_DDS_to_ADDB:-false} ; then
        echo "\"${1}\" : ${_n_ims} shasum images/${#_a_refDS[@]} different data-shasums values..."
        echo "Two images with one ADDB image, relinking all images to the ADDB image..."
        _dn=$(dirname "${1}")
        _bn=$(basename "${1}")
        fix_dir=${_dn}/fix_${_bn}
        mv "${1}" "${fix_dir}"
        im_ADDB=$(imageDB_shasums_of_ADDB_im "${fix_dir}")
        find "${fix_dir}" \( \
             -iname \*.heic \
          -o  -iname \*.heiv \
          -o  -iname \*.jpg \
          -o  -iname \*.jpeg \
          -o  -iname \*.jpe \
          -o  -iname \*.png \
          -o  -iname \*.avi \
          -o  -iname \*.mov \
          -o  -iname \*.mpg \
          -o  -iname \*.mpeg \
          -o  -iname \*.mp4 \
          -o  -iname \*.m4v \
          -o  -iname \*.flv \
          -o  -iname \*.tif \
          -o  -iname \*.tiff \
          -o  -iname \*.bmp \
          -o  -iname \*.psd \
          -o  -iname \*.cr2 \
          -o  -iname \*.dng \
          -o  -iname \*.gif \
        \) -a -type f | \
          while read file ; do
            if [ "$file" != "${im_ADDB}" ]; then
              execCmd "imageDB_rm_dtasi \"${file}\""
              execCmd "imageDB_relink_Archive_ims \"${file}\" \"${im_ADDB}\""
            fi
          done
        execCmd "rm -fr -v \"${fix_dir}\""
        [ -d "${fix_dir}" ] && mv "${fix_dir}" "${1}"
      elif [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 0 ]] && \
        [ ! -z "${im_KKCD7}" ] && \
        [ ! -z "${im_KKCD8}" ] && \
        true ; then
        echo "One image in 'KinderKrippe Hippos/CD7' and one in 'KinderKrippe Hippos/CD8', expunging the one in 'KinderKrippe Hippos/CD8'..."
        execCmd "imageDB_expung_from_Archive \"${im_KKCD8}\""
        execCmd "imageDB_expung_dtasi \"${im_KKCD8}\""
      elif [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 0 ]] && \
        [[ ${_n_Archive_ims_MP} -eq 2 ]] && \
        [[ ${_n_Archive_ims_MP_ov} -eq 1 ]] && \
        true ; then
        echo "\"${1}\" : ${_n_ims} shasum images/${#_a_refDS[@]} different data-shasums values..."
        echo "Two 'Mamie&Papi' images with one 'Old versions' image, relinking all images to the 'Old versions' image..."
        _dn=$(dirname "${1}")
        _bn=$(basename "${1}")
        fix_dir=${_dn}/fix_${_bn}
        mv "${1}" "${fix_dir}"
        im_ADDB=$(imageDB_shasums_of_Archive_im "${fix_dir}" "Family/Mamie&Papi/Old versions")
        find "${fix_dir}" \( \
           -iname \*.heic \
          -o  -iname \*.heiv \
          -o  -iname \*.jpg \
          -o  -iname \*.jpeg \
          -o  -iname \*.jpe \
          -o  -iname \*.png \
          -o  -iname \*.avi \
          -o  -iname \*.mov \
          -o  -iname \*.mpg \
          -o  -iname \*.mpeg \
          -o  -iname \*.mp4 \
          -o  -iname \*.m4v \
          -o  -iname \*.flv \
          -o  -iname \*.tif \
          -o  -iname \*.tiff \
          -o  -iname \*.bmp \
          -o  -iname \*.psd \
          -o  -iname \*.cr2 \
          -o  -iname \*.dng \
          -o  -iname \*.gif \
        \) -a -type f | \
          while read file ; do
            if [ "$file" != "${im_ADDB}" ]; then
              execCmd "imageDB_rm_dtasi \"${file}\""
              execCmd "imageDB_relink_Archive_ims \"${file}\" \"${im_ADDB}\""
            fi
          done
        execCmd "rm -fr -v \"${fix_dir}\""
        [ -d "${fix_dir}" ] && mv "${fix_dir}" "${1}"
      elif [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 0 ]] && \
        [[ ${_n_Archive_ims_MP} -eq 2 ]] && \
        [[ ${_n_Archive_ims_MP_dldm} -eq 1 ]] && \
        [[ ${_n_Archive_ims_MP_dlmd} -eq 1 ]] && \
        true ; then
        echo "\"${1}\" : ${_n_ims} shasum images/${#_a_refDS[@]} different data-shasums values..."
        echo "Two downloaded 'Mamie&Papi' images, relinking all images to the 'michel.doublier' image..."
        _dn=$(dirname "${1}")
        _bn=$(basename "${1}")
        fix_dir=${_dn}/fix_${_bn}
        mv "${1}" "${fix_dir}"
        im_ADDB=$(imageDB_shasums_of_Archive_im "${fix_dir}" "Family/Mamie&Papi/Downloaded Albums/michel.doublier")
        find "${fix_dir}" \( \
           -iname \*.heic \
          -o  -iname \*.heiv \
          -o  -iname \*.jpg \
          -o  -iname \*.jpeg \
          -o  -iname \*.jpe \
          -o  -iname \*.png \
          -o  -iname \*.avi \
          -o  -iname \*.mov \
          -o  -iname \*.mpg \
          -o  -iname \*.mpeg \
          -o  -iname \*.mp4 \
          -o  -iname \*.m4v \
          -o  -iname \*.flv \
          -o  -iname \*.tif \
          -o  -iname \*.tiff \
          -o  -iname \*.bmp \
          -o  -iname \*.psd \
          -o  -iname \*.cr2 \
          -o  -iname \*.dng \
          -o  -iname \*.gif \
        \) -a -type f | \
          while read file ; do
            if [ "$file" != "${im_ADDB}" ]; then
              execCmd "imageDB_rm_dtasi \"${file}\""
              execCmd "imageDB_relink_Archive_ims \"${file}\" \"${im_ADDB}\""
            fi
          done
        execCmd "rm -fr -v \"${fix_dir}\""
        [ -d "${fix_dir}" ] && mv "${fix_dir}" "${1}"
      elif [ -d "${1}" ] && \
        [[ ${_n_ADDB_ims} -eq 0 ]] && \
        [[ ${_n_Archive_ims_MP} -eq 1 ]] && \
        [[ ${_n_Archive_ims_AC_cad} -eq 1 ]] && \
        true ; then
        echo "\"${1}\" : ${_n_ims} shasum images/${#_a_refDS[@]} different data-shasums values..."
        echo "One 'Mamie&Papi' image and one 'downloaded AC', relinking all images to the 'downloaded AC' image..."
        _dn=$(dirname "${1}")
        _bn=$(basename "${1}")
        fix_dir=${_dn}/fix_${_bn}
        mv "${1}" "${fix_dir}"
        im_ADDB=$(imageDB_shasums_of_Archive_im "${fix_dir}" "Family/Alexis&Camille/ca.doublier")
        find "${fix_dir}" \( \
           -iname \*.heic \
          -o  -iname \*.heiv \
          -o  -iname \*.jpg \
          -o  -iname \*.jpeg \
          -o  -iname \*.jpe \
          -o  -iname \*.png \
          -o  -iname \*.avi \
          -o  -iname \*.mov \
          -o  -iname \*.mpg \
          -o  -iname \*.mpeg \
          -o  -iname \*.mp4 \
          -o  -iname \*.m4v \
          -o  -iname \*.flv \
          -o  -iname \*.tif \
          -o  -iname \*.tiff \
          -o  -iname \*.bmp \
          -o  -iname \*.psd \
          -o  -iname \*.cr2 \
          -o  -iname \*.dng \
          -o  -iname \*.gif \
        \) -a -type f | \
          while read file ; do
            if [ "$file" != "${im_ADDB}" ]; then
              execCmd "imageDB_rm_dtasi \"${file}\""
              execCmd "imageDB_relink_Archive_ims \"${file}\" \"${im_ADDB}\""
            fi
          done
        execCmd "rm -fr -v \"${fix_dir}\""
        [ -d "${fix_dir}" ] && mv "${fix_dir}" "${1}"
      elif [ -d "${1}" ] && \
        true ; then
        _n_ADDB_ims_str=${_n_ADDB_ims}
        [[ ${_n_ADDB_ims} -eq 0 ]] && _n_ADDB_ims_str="no"
        unset _n_ADDB_ims_str_s
        [[ ${_n_ADDB_ims} -ge 2 ]] && _n_ADDB_ims_str_s="s"
        echo "\"${1}\" : ${_n_ims} shasum images == ${#_a_refDS[@]} different data-shasums values, ${_n_ADDB_ims_str} ADDB image${_n_ADDB_ims_str_s}, keeping all..."
        execCmd "imageDB_keep_remaining_dup_dtasis \"${1}\""
      fi
    elif [ -d "${1}" ] && \
      true ; then
      _n_ADDB_ims=$(imageDB_ADDB_im "${1}" | wc -l)
      _n_ADDB_ims_str=${_n_ADDB_ims}
      [[ ${_n_ADDB_ims} -eq 0 ]] && _n_ADDB_ims_str="no"
      unset _n_ADDB_ims_str_s
      [[ ${_n_ADDB_ims} -ge 2 ]] && _n_ADDB_ims_str_s="s"
      if [[ ${_n_ims} -eq ${#_a_refDS[@]} ]]; then
        echo "\"${1}\" : ${_n_ims} shasum == ${#_a_refDS[@]} different data-shasums values, ${_n_ADDB_ims_str} ADDB image${_n_ADDB_ims_str_s}, keeping all..."
        [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
        [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
        execCmd "imageDB_keep_remaining_dup_dtasis \"${1}\""
      else
        echo "\"${1}\" : ${_n_ims} shasum images/${#_a_refDS[@]} different data-shasums values, ${_n_ADDB_ims_str} ADDB image${_n_ADDB_ims_str_s}, not doing anything..."
        [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
        [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
      fi
    fi
  fi
  [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
  [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
  reset_vbose
}
################################################################################
imageDB_ignore_PhotoBooth_dtasi_dups() {
  # If all the files in the dtasi duplicate directory were created by PhotoBooth,
  # ignore because PhotoBooth is crap on header info...
  if [[ \
    $(exiftool -T -keywords "${1}" | grep "Photo Booth" | wc -l) \
    -eq \
    $(ls -1 "${1}" | wc -l) \
  ]]; then
    echo "'${1}':: All images generated by Photo Booth, ignoring duplicate dtasis..."
    dtasi=$(basename "${1}")
    execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\""
    execCmd "mv -v \"${1}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/\""
    execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
    execCmd "ln -f ${vbose:+-v} \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/\"* \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
  fi
}
################################################################################
imageDB_manually_rotate90() {
  execCmd "mv \"${1}\" \"${1}_original\""
  execCmd "jpegtran -copy all -rotate 90 \"${1}_original\" > \"${1}\""
  execCmd "imageDB_relink_Archive_ims \"${1}_original\" \"${1}\""
  execCmd "rm -f${vbose:+v} \"${1}_original\""
}
################################################################################
imageDB_manually_rotate90_Ile_de_Re_Aq_ims() {
  # M&C-a20-139-3963_img.jpg = 2fdb5423e3de804f3bda3e0b57b62f4d5390a91bf6bd0197cedf9558843498adb9577a16df49723bb7c48d7510373318b36d5686dc6f83fc5cfaee89af7f9b90
  # M&C-a20-139-3970_img.jpg = 12f48801fdefabf7a72e53f62b5860fab93bd3c75ce8afc386d4f8c742f8f614e1f6a2b341d05f27169dac34815a46571a2f65005b2fcc3810e582e58a0248a0
  AD=$(dirname "${ADDB}")
  for F in \
    "Our Pictures/Holidays/France/200606/Ile de Re/Aquarium/M&C-a20-139-3963_img.jpg" \
    "Our Pictures/Holidays/France/200606/Ile de Re/Aquarium/M&C-a20-139-3970_img.jpg" \
    ; do
      imageDB_manually_rotate90 "${AD}/${F}"
  done
}
################################################################################
imageDB_relink_Ile_de_Re_Aq_ims() {
  AD=$(dirname "${ADDB}")
  cd "${AD}/Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/David_IleRé_Juin06/Aquarium"
  for F in M\&C-a20-139-*.jpg ; do
    FF="${AD}/Our\ Pictures/Holidays/France/200606/Ile\ de\ Re/Aquarium/$F"
    [ -e "${FF}" ] && [ $(stat -f %i "${F}") != $(stat -f %i "${FF}") ] && imageDB_relink_Archive_ims "${F}" "${FF}"
  done
  for F in 139_* ; do
    FF=$(echo "${AD}/Our Pictures/Holidays/France/200606/Ile de Re/Aquarium/M&C-a20-${F/_/-}" | gsed -e 's/.JPG/_img.jpg/')
    [ -e "${FF}" ] && [ $(stat -f %i "${F}") != $(stat -f %i "${FF}") ] && imageDB_relink_Archive_ims "${F}" "${FF}"
    FF=$(echo "${AD}/Our Pictures/Holidays/France/200606/Ile de Re/Aquarium/M&C-a20-${F}" | gsed -e 's/.JPG/_img.jpg/')
    [ -e ]
  done
}
################################################################################
imageDB_unlink_redundant_ADDB_MCs() {
  AD=$(dirname "${ADDB}")
  for F in "${ADDB}/M&C"-???-???_????_img.jpg ; do
    echo "------------------------"
    echo "\"${F}\""
    FF=${ADDB}/$(basename "${F}" | gsed -e 's/_/-/')
    _n_Archive_ims=$(imageDB_Archive_im "${F}" | wc -l)
    if [ -e "${FF}" ]; then
      if [[ $(stat -f %i "${F}") -eq $(stat -f %i "${FF}") ]]; then
        execCmd "\rm -f \"${F}\""
      else
        if [[ ${_n_Archive_ims:--1} -eq 0 ]]; then
          execCmd "imageDB_expung_dtasi \"${F}\""
        else
          imageDB_Archive_im "${F}"
        fi
      fi
    else
      if [[ ${_n_Archive_ims:--1} -ge 1 ]]; then
        bnF=$(basename "${F}")
        bnFF=$(basename "${FF}")
        find "${AD}" -name "${bnF}" | \
          while read file ; do
            dn=$(dirname "${file}")
            execCmd "mv -v \"${file}\" \"${dn}/${bnFF}\""
          done
      fi
    fi
  done
}
################################################################################
imageDB_ignore_HTCOneS_dtasi_dups() {
  # If all the files in the dtasi duplicate directory were created by PhotoBooth,
  # ignore because PhotoBooth is crap on header info...
  if [[ \
    $(exiftool -T -Model "${1}" | grep "HTC One S" | wc -l) \
    -eq \
    $(ls -1 "${1}" | wc -l) \
  ]]; then
    echo "'${1}':: All images generated by an HTC One S, ignoring duplicate dtasis..."
    dtasi=$(basename "${1}")
    execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\""
    execCmd "mv -v \"${1}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/\""
    execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
    execCmd "ln -f ${vbose:+-v} \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/\"* \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
  fi
}
################################################################################
imageDB_ignore_SQ907B_EZ_Cam_dtasi_dups() {
  # If all the files in the dtasi duplicate directory were created by PhotoBooth,
  # ignore because PhotoBooth is crap on header info...
  if [[ \
    $(exiftool -T -Model "${1}" | grep "SQ907B EZ-Cam" | wc -l) \
    -eq \
    $(ls -1 "${1}" | wc -l) \
  ]]; then
    echo "'${1}':: All images generated by an SQ907B EZ-Cam, ignoring duplicate dtasis..."
    dtasi=$(basename "${1}")
    execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\""
    execCmd "mv -v \"${1}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/\""
    execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
    execCmd "ln -f ${vbose:+-v} \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}/\"* \"${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum/${dtasi:0:7}/${dtasi}\""
  fi
}
################################################################################
imageDB_relocate_picasaoriginals() {
  AD=$(dirname "${ADDB}")
  _PWD=$(pwd)
  cd "${AD}"
  mkdir -p picasaoriginals
  find . \
     -name .picasaoriginals | \
      while read dir ; do
        ddir=$(dirname "${dir}")
        execCmd "mkdir -p \"picasaoriginals/${ddir}\""
        execCmd "mv -v \"${dir}\" \"picasaoriginals/${ddir}/\""
      done
  find picasaoriginals \( \
     -iname \*.heic \
    -o  -iname \*.heiv \
    -o  -iname \*.jpg \
    -o  -iname \*.jpeg \
    -o  -iname \*.jpe \
    -o  -iname \*.png \
    -o  -iname \*.avi \
    -o  -iname \*.mov \
    -o  -iname \*.mpg \
    -o  -iname \*.mpeg \
    -o  -iname \*.mp4 \
    -o  -iname \*.m4v \
    -o  -iname \*.flv \
    -o  -iname \*.tif \
    -o  -iname \*.tiff \
    -o  -iname \*.bmp \
    -o  -iname \*.psd \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
  \) -a -type f | \
    while read file ; do
      imageDB_rm_dtasi "${file}"
    done
  cd "${_PWD}"
}
################################################################################
imageDB_do_relinking() {
  cd "${ADDB:-/Archive/imageDB/getImgsFromFCard.DB}"
  _i=0
  _ii=${1:-0}  # Start from iter...
  unset do_rsync
  if [[ ${_ii} == 0 ]] ; then
    rm -fr .??*
    for F in M\&C-a20-???_????_img.jpg ; do
      FF=${F/_/-}
      if [ -e "${FF}" ]; then
        #s1=$(exiftool -T -YCbCrSubSampling "$F" | awk '{print $1}')
        #s2=$(exiftool -T -YCbCrSubSampling "$FF" | awk '{print $1}')
        imageDB_expung_from_Archive "$F"
      fi
    done
    find "${ADDB:-/Archive/imageDB/getImgsFromFCard.DB}/../Our Pictures" \
      -name M\&C-a20-\?\?\?_\?\?\?\?_img.jpg | \
        while read F ; do
          FF=${F/_/-}
          if [ -e "${FF}" ]; then
            #s1=$(exiftool -T -YCbCrSubSampling "$F" | awk '{print $1}')
            #s2=$(exiftool -T -YCbCrSubSampling "$FF" | awk '{print $1}')
            imageDB_expung_from_Archive "$F"
          fi
        done
    ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.imageDB_relink_duplicates --ADDB "${ADDB}" --init
  else
    for _j in $(gseq $_ii) ; do
      (( _i=_j-1 ))
      if [ ! -d ${SHDB:-${ADDB:-.}}/.${_i} ]; then
        errorLog "Can't find '${SHDB:-${ADDB:-.}}/.${_i}', can't continue."
        return
        #exit 1
      fi
    done
    if [ -d ${SHDB:-${ADDB:-.}}/.${_ii} ]; then
      if [ -d .dtasi ] || [ -d .shasum ]; then
        [ ! -d tmp ] && mkdir tmp
        mv .{d,s}* tmp/
        rm -fr tmp &
      fi
      mv -v ${SHDB:-${ADDB:-.}}/.${_i}/.{d,s}* .
    else
      do_rsync=false
    fi
  fi
  ${do_rsync:-true} && rsync --delete --link-dest="${ADDB}" -avxHAXtUN "${ADDB}"/.{d,s}* "${SHDB:-${ADDB:-.}}"/.${_i}/

  unset rm_dup_shasums
  cd "${ADDB:-/Archive/imageDB/getImgsFromFCard.DB}/.."
  mv -v "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes Images_2" .
  mv -v "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1" .
  mv -v "Our Pictures/Family" .
  _i=0
  for D in \
    "FaceBook" \
    "Incoming" \
    "Movies" \
    "New" \
    "Not for Public" \
    "Panoramas" \
    "Scans" \
    "Technical Pictures" \
    "WWW Pictures" \
    "Our Pictures" \
    "Family" \
    "Mes Images_2" \
    "Mes images 1" \
  ; do
    (( _i++ ))
    if [[ ${_i} -ge ${_ii} ]]; then
      if [ -d "$D" ]; then
        ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.imageDB_relink_duplicates --ADDB "${ADDB}" --dir "$D"
        rsync --delete --link-dest="${ADDB}" -avxHAXtUN "${ADDB}"/.{d,s}* "${SHDB:-${ADDB:-.}}"/.${_i}/
      fi
    fi
  done
  cd "${ADDB:-/Archive/imageDB/getImgsFromFCard.DB}/.."
  mv -v "Family" "Our Pictures/"
  mv -v "Mes images 1" "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/"
  mv -v "Mes Images_2" "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/"
  # correct datetimeoriginal for D40s.
  find Our\ Pictures \
      -iname \*.jpg -a -type f | \
      while read file ; do
        execCmd "imageDB_D40_correct_datetimeoriginal \"$file\""
      done
  # Some manualish fixes...
  imageDB_manually_rotate90_Ile_de_Re_Aq_ims
  imageDB_relink_Ile_de_Re_Aq_ims
  find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \
    -type d -depth 1 | \
      while read dir ; do
        execCmd "imageDB_ignore_PhotoBooth_dtasi_dups \"$dir\""
        execCmd "imageDB_ignore_HTCOneS_dtasi_dups \"$dir\""
        execCmd "imageDB_ignore_SQ907B_EZ_Cam_dtasi_dups \"$dir\""
      done
  ## Fix specific duplicates
  find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \( \
    -name "1990:"\* \
    -o -name "2002:11:07_"\* \
    -o -name "2009:"\* \
    -o -name "2009:09:02_"\* \
    -o -name "2009:11:21_"\* \
    -o -name "2010:11:24_"\* \
    -o -name "2010:12:25_"\* \
    -o -name "2011:06:18"\* \
    -o -name "2012:02:24"\* \
    \) -a -type d -a -depth 1 | \
      while read dir ; do
        echo "\"${dir}\""
        _dn=$(dirname "${dir}")
        _bn=$(basename "${dir}")
        fix_dir=${_dn}/fix_${_bn}
        mv "${dir}" "${fix_dir}"
        find "${fix_dir}" \( \
           -iname \*.heic \
          -o  -iname \*.heiv \
          -o  -iname \*.jpg \
          -o  -iname \*.jpeg \
          -o  -iname \*.jpe \
          -o  -iname \*.png \
          -o  -iname \*.avi \
          -o  -iname \*.mov \
          -o  -iname \*.mpg \
          -o  -iname \*.mpeg \
          -o  -iname \*.mp4 \
          -o  -iname \*.m4v \
          -o  -iname \*.flv \
          -o  -iname \*.tif \
          -o  -iname \*.tiff \
          -o  -iname \*.bmp \
          -o  -iname \*.psd \
          -o  -iname \*.cr2 \
          -o  -iname \*.dng \
          -o  -iname \*.gif \
        \) -a -type f | \
          while read file ; do
            execCmd "imageDB_expung_dtasi \"${file}\""
            execCmd "imageDB_shasum_dtasi_links \"${file}\""
            execCmd "rm \"${file}\""
          done
        execCmd "rm -fr \"${fix_dir}\""
      done
  echo "-----------------------------------------------------" ;\
  echo "-----------------------------------------------------" ;\
  echo "-----------------------------------------------------" ;\
  find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \
    -type d -depth 1 -name "2"\* | \
      while read dir ; do
        execCmd "imageDB_check_for_identical_data_shasums \"$dir\""
      done | tee cfids-$(datetime).log

  find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \
    -type d -depth 1  | \
      while read dir ; do
         execCmd "imageDB_check_for_identical_data_shasums \"$dir\"";
      done | tee cfids-$(datetime).log
  # Keep all these dirs, all shasums and data_shasums are unique...
  find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \( \
      -name "0000\:00\:00_00\:00\:00_"\* \
      -o -name "1979"\* \
    \) -a -type d -a -depth 1 | \
      while read dir ; do
        echo "\"${dir}\""
        execCmd "imageDB_keep_remaining_dup_dtasis \"${dir}\""
      done
  # Still to do...
  # move complete Mamie\&Papi out of Our\ Pictures
  # rsync (no-hardlinks) Mamie\&Papi back into Our\ Pictures
  # re-do Mamie\&Papi with un-linking the 2nd-found version of any image...

  if false ; then
    # The following are only supposed to be useful after making chnages to, for example,
    # imageDB_dtasi() which thus changes the dtasi dir names, so the following is about
    # updating the exisiting dtasi dirnames to whatever the new one will be...

    ## After updating imageDB_dtasi to include createdate/datetimeoriginal AND modifydate
    ## And to include SubSecTimeOriginal/SubSecTime
    ## Fix all duplicate directory names...
    find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \
      -a -type d -a -depth 1 | \
        while read dir ; do
          echo "\"${dir}\""
          _dn=$(dirname "${dir}")
          _bn=$(basename "${dir}")
          fix_dir=${_dn}/fix_${_bn}
          mv "${dir}" "${fix_dir}"
          find "${fix_dir}" \( \
             -iname \*.heic \
            -o  -iname \*.heiv \
            -o  -iname \*.jpg \
            -o  -iname \*.jpeg \
            -o  -iname \*.jpe \
            -o  -iname \*.png \
            -o  -iname \*.avi \
            -o  -iname \*.mov \
            -o  -iname \*.mpg \
            -o  -iname \*.mpeg \
            -o  -iname \*.mp4 \
            -o  -iname \*.m4v \
            -o  -iname \*.flv \
            -o  -iname \*.tif \
            -o  -iname \*.tiff \
            -o  -iname \*.bmp \
            -o  -iname \*.psd \
            -o  -iname \*.cr2 \
            -o  -iname \*.dng \
            -o  -iname \*.gif \
          \) -a -type f | \
            while read file ; do
              execCmd "imageDB_rm_dtasi \"${file}\""
              execCmd "imageDB_shasum_dtasi_links \"${file}\""
              execCmd "rm \"${file}\""
            done
          execCmd "rm -fr \"${fix_dir}\""
        done
    # resolve data-shasum duplicates...
    find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \
      -type d -depth 1 -name "2"\* | \
        while read dir ; do
          echo "-----------------------------------------------------"
          echo "\"${dir}\""
          execCmd "imageDB_check_for_identical_data_shasums \"$dir\""
        done ;\
    # Update all existing dtasi...
    find "${SHDB:-${ADDB:-.}}/.dtasi" "${SHDB:-${ADDB:-.}}/.dtasi/same_data_checksum" \( \
        -name "-"\* \
        -o -name [0-9]\* \
      \) -a -type d -a -depth 1 | \
      while read ddir ; do
        find "${ddir}" -a -type d -a -depth 1 | \
          while read dir ; do
            find "${dir}" \( \
               -iname \*.heic \
              -o  -iname \*.heiv \
              -o  -iname \*.jpg \
              -o  -iname \*.jpeg \
              -o  -iname \*.jpe \
              -o  -iname \*.png \
              -o  -iname \*.avi \
              -o  -iname \*.mov \
              -o  -iname \*.mpg \
              -o  -iname \*.mpeg \
              -o  -iname \*.mp4 \
              -o  -iname \*.m4v \
              -o  -iname \*.flv \
              -o  -iname \*.tif \
              -o  -iname \*.tiff \
              -o  -iname \*.bmp \
              -o  -iname \*.psd \
              -o  -iname \*.cr2 \
              -o  -iname \*.dng \
              -o  -iname \*.gif \
            \) -a -type f | head -n 1 | \
              while read file ; do
                dtasi=$(imageDB_dtasi "${file}")
                [ ! -d "${ddir}/${dtasi}" ] && execCmd "mv -v \"${dir}\" \"${ddir}/${dtasi}\""
              done
          done
        done
    # Check for orphaned shasums...
    find .shasum/ -type f | \
      while read file ; do \
        ims=$(imageDB_Archive_im "${file}")$(imageDB_ADDB_im "${file}") ; [ -z "${ims}" ] && echo "\"$file\""
      done
  fi
}
################################################################################
imageDB_for_Photos_rm_dups() {

  cd "${ADDB:-/Archive/imageDB.19XX-2020.Photos/getImgsFromFCard.DB}/.."
  mv -v "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes Images_2" .
  mv -v "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1" .
  mv -v "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012" .
  mv -v "Our Pictures/Family" .
  for D in \
    "Our Pictures" \
    "Movies" \
    "Papa Photos 11-2012" \
    "Mes Images_2" \
    "Mes images 1" \
    "Family" \
    "FaceBook" \
    "Incoming" \
    "Not for Public" \
    "Panoramas" \
    "Scans" \
    "Technical Pictures" \
    "WWW Pictures" \
  ; do
    if [ -d "$D" ]; then
      ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.imageDB_relink_duplicates --ADDB "${ADDB}" --dir "$D" --rm_dup_shasums
    fi
  done
  cd "${ADDB:-/Archive/imageDB.19XX-2020.Photos/getImgsFromFCard.DB}/.."
  mv -v "Family" "Our Pictures/"
  mv -v "Papa Photos 11-2012" "Our Pictures/Family/Mamie&Papi/"
  mv -v "Mes images 1" "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/"
  mv -v "Mes Images_2" "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/"
  rm -frv \
    .Other~ \
    .Photos \
    Incoming \
    Picasa3 \
    dk.test \
    getImgsFromFCard.DB \
    iPads \
    iPhones \
    picasaoriginals \
    Not\ for\ Public \
    ht.py \

}
################################################################################
imageDB_relocate_corrupted_files() {
  for F in \
    "Technical Pictures/ESO/Paranal" \
    "Our Pictures/00Nous/David Gwenhael/Movies/David_5sept07.avi" \
    "Our Pictures/00Nous/David Gwenhael/Movies/David_Couture_Test_Sept.avi" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes Images_2/JoanPictures/IMGP1906.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes Images_2/Mathilde/Mathilde_finJuin_miJuil2007/DSC_2260.JPG" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0083.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0084.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0147.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0148.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0149.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0150.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0182.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0183.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0185.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0186.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0208.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0209.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0215.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0216.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0229.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0242.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0264.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0265.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/BrianJoan_2006/Video/IMGP0313.AVI" \
    "Our Pictures/Family/Nana&GrandDad/In Germany & France 2006/nanas-s5z-100-045"{4,5,6,7}"_mvi.avi" \
    "Our Pictures/Holidays/New Zealand/200903-200904/JVDS TRIP 04 09 0"{7{6,7,8,9},8{0,1,2,3,4,5}}".avi" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/David_IleRé_Juin06/s45-135-3532.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/David_IleRé_Juin06/Aquarium/s45-136-3638.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/David_IleRé_Juin06/Aquarium/s45-136-3639.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/David_IleRé_Juin06/Aquarium/s45-136-3637.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/David_IleRé_Juin06/Aquarium/s45-136-3636.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/David_IleRé_Juin06/Aquarium/s45-136-3640.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/David_IleRé_Juin06/s45-136-3651.AVI" \
    "Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/David/David_IleRé_Juin06/s45-136-3650.AVI" \
    "Our Pictures/Family/Jerome/MyAlbum-1 au 7 Mai/Planche contact{1,2,3}.bmp" \
    ; do
    if [ -e "imageDB.19XX-2020.Photos/${F}" ]; then
      dn=$(dirname "${F}")
      mkdir -p "imageDB.corrupted/${dn}"
      echo "Relocating '${F}'"
      mv -v "imageDB.19XX-2020.Photos/${F}" "imageDB.corrupted/${dn}" || break
      for Idb in imageDB.19XX-2020* imageDB\@2020-12-12* ; do
        [ -e "${Idb}/${F}" ] && rm -frv "${Idb}/${F}"
      done
    fi
  done
}
################################################################################
imageDB_corrupted_avi_2_m4v() {
  debug="-D"
  unset dryRun
  _avi="${1}"
  _m4v=$(echo "${_avi}" | gsed \
    -e 's/.avi$/.m4v/i' \
    -e 's/.flv$/.m4v/i' \
  )
  if [ -e "${_m4v}" ]; then
    execCmd "imageDB_expung_dtasi \"${_m4v}\""
    execCmd "rm -fv \"${_m4v}\""
  fi
  if [ ! -e "${_m4v}" ]; then
    execCmd "HandBrakeCLI -i \"${_avi}\" -o \"${_m4v}\""
    execCmd "exiftool \
      -addTagsFromFile \"${_avi}\" \
      \"-xmp:all<all\" \"-Keywords-<Keywords\" \"-Keywords+<Keywords\" \
      \"${_m4v}\" \
      -overwrite_original_in_place -preserve"
    # check for -datetimeoriginal, set to birthtime if not present...
    _dto=$(exiftool -d %s -T -datetimeoriginal "${_m4v}" | gsed -e 's/-//g' | awk '{print $1}')
    _cd=$(exiftool -d %s -T -createdate "${_m4v}" | gsed -e 's/-//g' | awk '{print $1}')
    eval $(stat -s "${_avi}")
    execCmd "exiftool -d %s \
      -createdate=${_dto:-${st_birthtime}} \
      -datetimeoriginal=${_dto:-${st_birthtime}} \
      \"${_m4v}\" \
      -overwrite_original_in_place -preserve"
    for D in $(ls -d ../imageDB{.19,\@20}* 2>/dev/null) ; do
      execCmd "ln -fv \"${_m4v}\" \"${D}/${_m4v}\""
    done
    execCmd "imageDB_shasum_dtasi_links \"${_m4v}\""
  fi
}
################################################################################
imageDB_m4vs_relink_shasum_dtasi_by_samefile() {
  debug="-D"
  unset dryRun
  shasum_original=$(find "$SHDB"/.shasum -samefile "${1}")
  if [ ! -z "${shasum_original}" ]; then
    shasum_original=$(basename "${shasum_original}" | ${VJPD_FUNCTIONS_SED} -e 's/\..*$//')
    _save_SHDB="$SHDB"
    export SHDB="/Volumes/LaCie Disk/Archive/.imageDB.shasumDB"
    execCmd "imageDB_expung_dtasi \"${1}\""
    execCmd "imageDB_shasum_dtasi_links \"${1}\""
    export SHDB="/Volumes/LaCie Disk/Archive/.imageDB.shasumDB.19XX-2020.Photos"
    execCmd "imageDB_expung_dtasi \"${1}\""
    execCmd "imageDB_shasum_dtasi_links \"${1}\""
    export SHDB="${_save_SHDB}"
    unset _save_SHDB
    unset debug
  fi
  unset shasum_original
}
################################################################################
imageDB_add_fileextension() {
  if [ -e "${1}" ]; then
    fextn=$(exiftool -t -S -q -filetypeextension "${1}")
    if [ ! -z "${fextn}" ]; then
      execCmd "mv -v \"${1}\" \"${1}.${fextn}\""
      execCmd "imageDB_shasum_dtasi_links \"${1}.${fextn}\""
      #execCmd "imageDB_shasum_dtasi_links \"${1}\""
    fi
  fi
}
################################################################################
imageDB_compare_two_dirs() {
  find "${1}" \( \
        -iname \*.heic \
    -o  -iname \*.heiv \
    -o  -iname \*.jpg \
    -o  -iname \*.jpeg \
    -o  -iname \*.jpe \
    -o  -iname \*.png \
    -o  -iname \*.avi \
    -o  -iname \*.mov \
    -o  -iname \*.mpg \
    -o  -iname \*.mpeg \
    -o  -iname \*.mp4 \
    -o  -iname \*.m4v \
    -o  -iname \*.flv \
    -o  -iname \*.tif \
    -o  -iname \*.tiff \
    -o  -iname \*.bmp \
    -o  -iname \*.psd \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
  \) -a -type f | \
    while read file ; do
      bnfile=$(basename "${file}")
      if [ -e "${2}/${bnfile}" ]; then
        echo $bnfile
        s1=$(imageDB_shasum "${file}")
        s2=$(imageDB_shasum "${2}/${bnfile}")
        [ "${s1}" == "${s2}" ] && rm -v "${2}/${bnfile}"
      fi
    done
}
################################################################################
imageDB_cp_xattrs() {
  execCmd "xattr -c \"${2}\""
  IFS=$'\n' attr_names=($(xattr "$1"))
  for attr in ${attr_names[@]} ; do
    verboseLog "Copying $attr..."
    value=$(xattr -p -x "$attr" "$1" | tr -d " \n")
    xattr -w -x "$attr" "$value" "$2"
  done
}
################################################################################
imageDB_relink_one_Photos_clones() {
  DBimage="${1}"
  shasum=$(imageDB_shasum "${DBimage}").$(exiftool -T -fileTypeExtension "${DBimage}")
  shasum_file="${SHDB:-${ADDB:-.}}/.shasum/${shasum:0:3}/${shasum}"
  if [ ! -e "${shasum_file}" ]; then
    # This shouldn't actually happen...
    execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.no_Photos_shasum/${shasum:0:3}/\""
    execCmd "ln -fv \"${DBimage}\" \"${SHDB:-${ADDB:-.}}/.no_Photos_shasum/${shasum:0:3}/${shasum}\""
  else
    # Good... This shasum already exists...
    # copy the extended attritbutes from the Photos file to the original...
    execCmd "imageDB_cp_xattrs \"${DBimage}\" \"${shasum_file}\""
    # ...and now relink the Photos file to the original...
    execCmd "ln -f${qvbose:+v} \"${shasum_file}\" \"${DBimage}\""
  fi

}
################################################################################
imageDB_relink_Photos_clones() {

  PICS_DIR=${PICS_DIR:-/Archive/imageDB/.Pictures}
  PHOTOS_DIR=${PHOTOS_DIR:-${PICS_DIR}/Photos Library.photoslibrary}
  qvbose="-v"
  [ ! -z "${quiet}"] && unset qvbose

  find "${PHOTOS_DIR}"/originals \
    -a -type f -a -links 1 |
      while read file ; do
        imageDB_relink_one_Photos_clones "${file}"
      done
}
################################################################################
imageDB_set_datetimeoriginal_dir() {

  execCmd "exiftool \
    -datetimeoriginal=\"${1:-2000}:${2:-01}:${3:-01} ${4:-12}:${5:-00}:${6:-00}\" \
    . \
    -overwrite_original_in_place -preserve \
    "
  execCmd "exiftool \
    '-datetimeoriginal+<0:0:\${filesequence}0' \
    . \
    -overwrite_original_in_place -preserve \
    -fileOrder filename \
    "
  execCmd "exiftool \
    -T -filename -datetimeoriginal \
    . \
    -fileOrder filename \
    "
}
################################################################################
imageDB_migrate_to_Photos() {

  # imageDB directory history...
  # imageDB@2020-12-12.original        : rsync of imageDB on 2020-12-12
  # imageDB@2020-12-12.relinked        : rsync of imageDB on 2021-04-01 after fixing all the duplicates...
  #                                      i.e. the result of doing imageDB_do_relinking()
  # imageDB@2020-12-12.relinked.sorted : rsync of imageDB on 2021-05-16 after sorting most of "New" into directories...
  # imageDB.19XX-2020                  : 2021-06-05 :: renamed imageDB to imageDB.19XX-2020, identical to imageDB@2020-12-12.relinked.sorted
  # imageDB.19XX-2020.Photos           : 2021-06-16 :: rsync copy of imageDB.19XX-2020
  # 2021-06-??                         : ran this method on imageDB.19XX-2020.Photos
  # 2021-06-??                         : imported imageDB.19XX-2020.Photos into Photos on Jarvis

  # prepare with:
  cd "/Volumes/LaCie Disk/Archive"
  ## sudo chmod a-x <all_ims>
  [ ! -d imageDB.19XX-2020 ] && [ -e imageDB ] && sudo mv imageDB imageDB.19XX-2020
  [ ! -d imageDB@2020-12-12.relinked.sorted ] &&  \
      sudo rsync -avxHAXtUN \
          --link-dest "$(pwd)"/imageDB.19XX-2020/ \
          "$(pwd)"/imageDB.19XX-2020/ \
          "$(pwd)"/imageDB@2020-12-12.relinked.sorted/
  [ -d "imageDB.19XX-2020.Photos/Our Pictures/Nous" ] && \
    mv -v "imageDB.19XX-2020.Photos/Our Pictures/Nous" "imageDB.19XX-2020.Photos/Our Pictures/00Nous"
  find imageDB.19XX-2020 -name "Apple TV Photo Cache" -exec rm -frv "{}" \;
  sudo rsync -avxHAXtUN \
      --delete \
      --link-dest "$(pwd)"/imageDB.19XX-2020/ \
      "$(pwd)"/imageDB.19XX-2020/ \
      "$(pwd)"/imageDB.19XX-2020.Photos/
  [ -e "${SHDB}" ] && sudo rm -fr "${SHDB}"
  sudo mkdir -p "${SHDB}"
  sudo chown imageDB:imageDB "${SHDB}"
  sudo chmod g+w "${SHDB}"
  #
  #
  # rsync from Archive on one disk to another...
  # rsync options:
  # a: archive mode; equals -rlptgoD (no -H,-A,-X)
  # v: increase verbosity
  # x: don't cross filesystem boundaries
  # H: preserve hard links
  # A: preserve ACLs (implies --perms)
  # C: auto-ignore files in the same way CVS does
  # X: preserve extended attributes
  # t: preserve modification times
  # U: preserve access (use) times
  # N: preserve create times (newness) (critical for birthdate time)
  # Deliberately do NOT preserve Extended Attributes... (-A)
  sudo /opt/local/bin/rsync -avxHAXtUN \
    .imageDB.shasumDB \
    imageDB \
    .imageDB.shasumDB.19XX-2020.Photos \
    imageDB.19XX-2020.Photos \
    /Volumes/Samsung\ SSD\ T5/Archive/
  # run this method [started 2021-06-05]
  export LC_CTYPE=C # to avoid "sort: Illegal byte sequence" issues
  export ADDB="/Volumes/LaCie Disk/Archive/imageDB.19XX-2020.Photos/getImgsFromFCard.DB"
  export SHDB="/Volumes/LaCie Disk/Archive/.imageDB.shasumDB.19XX-2020.Photos"
  export PICS_DIR="/Volumes/LaCie Disk/Archive/imageDB/.Pictures"
  export PHOTOS_DIR="${PICS_DIR}/Photos Library.photoslibrary"
  . ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.functions.sh
  imageDB_for_Photos_rm_dups
  # 
  # Import imageDB into Photos...
  osascript ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.imageDB.ImportPhotoFolders.applescript \
    "imageDB.19XX-2020.Photos"
  #
  # re-link the clones in Photos back to the originals...
  imageDB_relink_Photos_clones
  #
  # Prepare the new imageDB directory...
  sudo mkdir -p "imageDB/.Pictures"
  sudo chown -R imageDB:imageDB "imageDB"
  sudo chmod -R g+w "imageDB"
}
################################################################################
imageDB_sync_LaCies() {
  execCmd "sudo /opt/local/bin/rsync -avxHAXtUN --delete \
    --exclude .DS_Store \
    --exclude Apple\ TV\ Photo\ Cache \
    --exclude iPod\ Photo\ Cache \
    \"/Volumes/LaCie Disk/Archive/imageDB.19XX-2020.Photos\" \
    \"/Volumes/LaCie Disk/Archive/.imageDB.shasumDB.19XX-2020.Photos\" \
    \"/Volumes/LaCie/Archive/\" \
"
}

################################################################################
imageDB_set_env_on_zondar() {
  export LC_CTYPE=C # to avoid "sort: Illegal byte sequence" issues
  export VJPD_ROOT="/Users/jpritcha/src/vjpd"
  export ADDB="/Volumes/LaCie Disk/Archive/imageDB/getImgsFromFCard.DB"
  export SHDB="/Volumes/LaCie Disk/Archive/.imageDB.shasumDB"
  export PICS_DIR="/Volumes/LaCie Disk/Archive/imageDB/.Pictures"
  export PHOTOS_DIR="${PICS_DIR}/Photos Library.photoslibrary"
  . ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.functions.sh
}
################################################################################
imageDB_set_env_on_zondar_for_Photos() {
  export LC_CTYPE=C # to avoid "sort: Illegal byte sequence" issues
  export VJPD_ROOT="/Users/jpritcha/src/vjpd"
  export ADDB="/Volumes/LaCie Disk/Archive/imageDB.19XX-2020.Photos/getImgsFromFCard.DB"
  export SHDB="/Volumes/LaCie Disk/Archive/.imageDB.shasumDB.19XX-2020.Photos"
  export PICS_DIR="/Volumes/LaCie Disk/Archive/imageDB/.Pictures"
  export PHOTOS_DIR="${PICS_DIR}/Photos Library.photoslibrary"
  . ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.functions.sh
}
################################################################################
imageDB_set_env_on_zondar_for_Photos_test() {
  export LC_CTYPE=C # to avoid "sort: Illegal byte sequence" issues
  export VJPD_ROOT="/Users/jpritcha/src/vjpd"
  export ADDB="/Users/jpritcha/Pictures/Photos_test/Archive/imageDB/getImgsFromFCard.DB"
  export SHDB="/Users/jpritcha/Pictures/Photos_test/Archive/.imageDB.shasumDB"
  export PICS_DIR="/Users/jpritcha/Pictures/Photos_test"
  export PHOTOS_DIR="${PICS_DIR}/Photos Library.photoslibrary"
  . ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.functions.sh
}
################################################################################
imageDB_set_env_on_rjander_for_JB_photos() {
  export LC_CTYPE=C # to avoid "sort: Illegal byte sequence" issues
  #export VJPD_ROOT="/Users/jpritcha/src/vjpd"
  export ADDB="/Volumes/JB_Elements/Archive/JB/JB_photos@2023-04-30.relinked/getImgsFromFCard.DB"
  export SHDB="/Volumes/JB_Elements/Archive/JB/.shasumDB.JB_photos@2023-04-30"
  export PICS_DIR="/Volumes/JB_Elements/Archive/JB/.Pictures"
  export PHOTOS_DIR="${PICS_DIR}/Photos Library.photoslibrary"
  . ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.functions.sh
  expunge_dtasis_with_dup_data_shasum=true
  unset expunge_dtasis_with_dup_data_shasum
}
################################################################################
JB_photos_cleanup() {

  # JB_photos directory history...
  # JB_photos@2023-04-30.originals       : All collected photos, excpt SCANs to be made...
  # JB_photos@2023-04-30.relinked        : rsync of JB_photos@2023-04-30.originals on 2023-04-30
  #                                        then relinked using method ???()

  # JB_photos@2023-04-30.relinked.sorted : rsync of JB_photos on 2021-05-16 after sorting most of "New" into directories...
  #                                      i.e. the result of doing JB_photos_do_relinking()
  # JB_photos.19XX-2020                  : 2021-06-05 :: renamed JB_photos to JB_photos.19XX-2020, identical to JB_photos@2020-12-12.relinked.sorted
  # JB_photos.19XX-2020.Photos           : 2021-06-16 :: rsync copy of JB_photos.19XX-2020
  # 2021-06-??                         : ran this method on JB_photos.19XX-2020.Photos
  # 2021-06-??                         : imported JB_photos.19XX-2020.Photos into Photos on Jarvis

  # prepare with:
  cd "/Volumes/JB_Elements/Archive/JB"
  mkdir -p rm ; mv JB_photos\@2023-04-30.relinked/ .shasumDB.JB_photos\@2023-04-30/ rm ; sleep 3600 && rm -fr rm
  cd "/Volumes/JB_Elements/Archive/JB"
  ## sudo chmod a-x <all_ims>
  [ ! -d JB_photos@2023-04-30.relinked ] && \
    [ -d JB_photos@2023-04-30.originals ] && \
      rsync -avxHAXtUN \
          --link-dest "$(pwd)"/JB_photos@2023-04-30.originals/ \
          "$(pwd)"/JB_photos@2023-04-30.originals/ \
          "$(pwd)"/JB_photos@2023-04-30.relinked/ \
      && \
      mv -v \
        "$(pwd)"/JB_photos@2023-04-30.relinked/Elements/Pictures/Pictures \
        "$(pwd)"/JB_photos@2023-04-30.relinked/Elements/New\ Folder \
        "$(pwd)"/JB_photos@2023-04-30.relinked/

  # run this method [started 2023-04-30]
  export LC_CTYPE=C # to avoid "sort: Illegal byte sequence" issues
  export ADDB="/Volumes/JB_Elements/Archive/JB/JB_photos@2023-04-30.relinked/getImgsFromFCard.DB"
  export SHDB="/Volumes/JB_Elements/Archive/JB/.shasumDB.JB_photos@2023-04-30"
  export PICS_DIR="/Volumes/JB_Elements/Archive/JB/.Pictures"
  export PHOTOS_DIR="${PICS_DIR}/Photos Library.photoslibrary"
  . ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.functions.sh
  expunge_dtasis_with_dup_data_shasum=true
  unset expunge_dtasis_with_dup_data_shasum
  sdt=$(gdate +%s)
  JB_photos_do_relinking
  edt=$(gdate +%s)
  (( elapsed_secs = $edt - $sdt ))
  echo Running time $(gdate -d@${elapsed_secs} -u +%H:%M:%S)
  # 
  # Import JB_photos into Photos...
  osascript ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.JB_photos.ImportPhotoFolders.applescript \
    "JB_photos.19XX-2020.Photos"
  #
  # re-link the clones in Photos back to the originals...
  imageDB_relink_Photos_clones
  #
  # Prepare the new JB_photos directory...
  sudo mkdir -p "JB_photos/.Pictures"
  sudo chown -R JB_photos:JB_photos "JB_photos"
  sudo chmod -R g+w "JB_photos"
}
################################################################################
JB_photos_do_relinking() {


  ADDB="${ADDB:-/Volumes/JB_Elements/Archive/JB/JB_photos@2023-04-30.relinked/getImgsFromFCard.DB}"
  [ ! -d "${ADDB}" ] && mkdir "${ADDB}"
  cd "${ADDB}/.."
  dnADDB=$(dirname "$(pwd)")
  #
  # fix a few special cases...
  find . \( \
     -iname frisco\* \
    -or -iname picture\ [1,2,p]\* \
    -or -iname 'Dec 25 06 Rachel' \
    \) -exec mv -v "{}" "{}".jpg \;
  #
  # set permissions...
  find . \( \
        -iname \*.heic \
    -o  -iname \*.heiv \
    -o  -iname \*.jpg \
    -o  -iname \*.jpeg \
    -o  -iname \*.jpe \
    -o  -iname \*.png \
    -o  -iname \*.avi \
    -o  -iname \*.mov \
    -o  -iname \*.mpg \
    -o  -iname \*.mpeg \
    -o  -iname \*.mp4 \
    -o  -iname \*.m4v \
    -o  -iname \*.flv \
    -o  -iname \*.tif \
    -o  -iname \*.tiff \
    -o  -iname \*.bmp \
    -o  -iname \*.psd \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
    -o  -iname \*.aae \
  \) -a -type f -exec chmod a-x "{}" \;
  # remove empty files...
  find . -empty -type f -delete -print
  # remove non photo/movie files...
  find . \( \
         -iname .Spotlight-V100 \
    -or -iname .fseventsd \
    -or -iname SecureII \
    -or -iname WindowsEasyTransfer \
    -or -iname 'System Volume Information' \
    -or -iname 'WD Smartware Pro Free Trial' \
  \) -exec rm -frv "{}" \;
  find . \( \
         -iname \*.mp3 \
    -or -iname \*.wma \
    -or -iname \*.wav \
    -or -iname Thumbs.db \
    -or -iname ZbThumbnail.info \
    -or -iname \*.lnk \
    -or -iname \*.ods \
    -or -iname \*.ods\# \
    -or -iname \*.odt \
    -or -iname \*.odt\# \
    -or -iname \*.html \
    -or -iname \*.xhtml \
    -or -iname \*.doc \
    -or -iname \*.exe \
    -or -iname \*.pdf \
    -or -iname \*.psf \
    -or -iname \*.pls \
    -or -iname \*.txt \
    -or -iname \*.iaf \
    -or -iname \*.xlr \
    -or -iname \*.xml \
    -or -iname TV \
    -or -iname \*.pub \
    -or -iname Part\ [0-9]\* \
    -or -iname .picasa.ini \
    -or -iname ehthumbs_vista.db \
    -or -iname \*.ini \
    -or -iname \*.inf \
    -or -iname \*.ico \
    -or -iname \*.eml \
    -or -iname \*.zip \
    -or -iname \*.pod \
    -or -iname albumart_\*.jpg \
    -or -iname albumartsmall.jpg \
    -or -iname Folder.jpg \
    -or -iname .DS_Store \
    -or -iname .dropbox.device \
  \) -exec rm -fv "{}" \;
  #
  # relink...
  for D in \
    "Pictures" \
    "Elements" \
    "DVDs" \
    "USB sticks" \
    "New Folder" \
    "makeMKV" \
  ; do
    if [ -d "$D" ]; then
      ${VJPD_ROOT:-/opt/vjpd}/bin/vjpd.imageDB_relink_duplicates \
        --ADDB "${ADDB}" \
        --dir "$D" \
        --rm_dup_shasums
    fi
  done
  # remove empty directories...
  find . -empty -type d -delete -print
  # Convert FLVs to M4Vs
  find . \( \
     -iname \*.avi \
    -or -iname \*.flv \
    -or -iname \*.mkv \
    \) |
      while read file ; do
        imageDB_corrupted_avi_2_m4v "${file}"
      done
  find . \( \
     -iname \*.avi \
    -or -iname \*.flv \
    -or -iname \*.mkv \
    \) -delete -print
  # Merge directories...
  mv -i DVDs/2005.first_try/* DVDs/2005
  rmdir DVDs/2005.first_try

  # sort duplicates...
  echo "-----------------------------------------------------" ;\
  echo "-----------------------------------------------------" ;\
  echo "-----------------------------------------------------" ;\
  sudo mkdir -pv "${dnADDB}"/JB_photos@2023-04-30.relinked.before_sorting_duplicates
  rsync -avxHAXtUN \
      --link-dest "${dnADDB}"/JB_photos@2023-04-30.relinked/ \
      "${dnADDB}"/JB_photos@2023-04-30.relinked/ \
      "${dnADDB}"/JB_photos@2023-04-30.relinked.before_sorting_duplicates/JB_photos@2023-04-30.relinked/
  rsync -avxHAXtUN \
      --link-dest "${dnADDB}"/.shasumDB.JB_photos\@2023-04-30/ \
      "${dnADDB}"/.shasumDB.JB_photos\@2023-04-30/ \
      "${dnADDB}"/JB_photos@2023-04-30.relinked.before_sorting_duplicates/.shasumDB.JB_photos\@2023-04-30/
  read -p "<Enter> " _d
  if false ; then
    # to copy back...
    cd "${SHDB}/.."
    dnADDB="$(pwd)"
    suf="almost"
    cd "${dnADDB}"
    mkdir ${suf}
    mv -v \
      "${dnADDB}"/JB_photos@2023-04-30.relinked/ \
      "${dnADDB}"/.shasumDB.JB_photos@2023-04-30/ \
      "${dnADDB}"/${suf}/
    rsync -avxHAXtUN \
        --link-dest "${dnADDB}"/JB_photos@2023-04-30.relinked.before_sorting_duplicates/ \
        "${dnADDB}"/JB_photos@2023-04-30.relinked.before_sorting_duplicates/ \
        "${dnADDB}"/
    cd "${dnADDB}"/JB_photos@2023-04-30.relinked
  fi

  echo "-----------------------------------------------------" ;\
  echo "-----------------------------------------------------" ;\
  echo "-----------------------------------------------------" ;\
  find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \
    -type d -depth 1 -name "2"\* | \
      while read dir ; do
        execCmd "JB_photos_check_for_identical_data_shasums \"$dir\""
      done | tee cfids-$(datetime).log

  find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \
    -type d -depth 1  | \
      while read dir ; do
         execCmd "JB_photos_check_for_identical_data_shasums \"$dir\"";
      done | tee cfids-$(datetime).log
  find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \
    -type d -depth 1  | \
      while read dir ; do
         execCmd "JB_photos_check_for_identical_data_shasums \"$dir\"";
      done | tee cfids-$(datetime).log
  find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \
    -type d -depth 1  | \
      while read dir ; do
         execCmd "JB_photos_check_for_identical_data_shasums \"$dir\"";
      done | tee cfids-$(datetime).log


  CFIDS=$(ls -tr cfids* | tail -n 1) ; \
  grep ^/Volumes/JB_Elements/Archive/JB/JB_photos@2023-04-30.relinked $CFIDS \
  | sed -e 's@\(^.*/\).*@\1@' | sed -e 's@ @_%_@g' > CFIDS ; \
  for D in \
    $(grep ^/Volumes/JB_Elements/Archive/JB/JB_photos@2023-04-30.relinked $CFIDS \
      | sed -e 's@\(^.*/\).*@\1@' | sort -u | sed -e 's@ @_%_@g') \
    ; do 
      echo $(grep "^${D}\$" CFIDS | wc -l) ${D}
    done | sort -rn > CFIDS.sort-rn
  find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \
    -type d -depth 1  | \
      while read dir ; do
         execCmd "JB_photos_check_for_identical_data_shasums \"$dir\"";
      done | tee cfids-$(datetime).log
  find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \
    -type d -depth 1  | \
      while read dir ; do
         execCmd "JB_photos_check_for_identical_data_shasums \"$dir\"";
      done | tee cfids-$(datetime).log


  if false ; then
    # Keep all these dirs, all shasums and data_shasums are unique...
    find "${SHDB:-${ADDB:-.}}/.dtasi/duplicates" \( \
        -name "0000\:00\:00_00\:00\:00_"\* \
        -o -name "1979"\* \
      \) -a -type d -a -depth 1 | \
        while read dir ; do
          echo "\"${dir}\""
          execCmd "imageDB_keep_remaining_dup_dtasis \"${dir}\""
        done
  fi

  # Final manualish cleanup...
  for D in ${SHDB:-${ADDB:-.}}/.dtasi/duplicates/* ; do \
    echo "-------------------------------------------"
    echo $D
    for F in $D/* ; do
      echo $F $(JB_photos_Archive_im $F)
    done
  done > last_duplicates_w_shasums.txt
  for D in ${SHDB:-${ADDB:-.}}/.dtasi/duplicates/* ; do \
    echo "-------------------------------------------"
    echo $D
    for F in $D/* ; do
      JB_photos_Archive_im $F
    done
  done > last_duplicates.txt
  for D in \
    "Elements/2015-11-08 Garden 2004/Pritchard" \
    "Pictures/Various 001" \
    "2015-11-08 Garden 2004/Oct Garden 04" \
    "2015-11-08 Garden 2004/July 25 04" \
    "Pictures/Brys 70th" \
    "2015-11-08 Garden 2004/Joining" \
    "Pictures/Joining" \
    "Johns Mun 2015/Joans iPad" \
    "Google+ Auto Backup/2014-06-20" \
    "Pictures/Dads slide show/038.JPG" \
  ; do
    echo "-------------------------------------------"
    echo "-------------------------------------------"
    echo "-------------------------------------------"
    for F in \
      $(grep "$D" last_duplicates_w_shasums.txt | awk '{print $1}') \
    ; do
      imageDB_expung_from_Archive "${F}"
      imageDB_expung_dtasi ${F}
    done
  done

  # Merge more directories...
  if true ; then
    mv -i New\ Folder/* Pictures
    rmdir New\ Folder
    mv DVDs/* Pictures/
    mv DVDs/Langkawi\ May\ 07/Langkawi\ May\ 07\ 005.jpg Pictures/Langkawi\ May\ 07/
    rmdir DVDs/Langkawi\ May\ 07/
    rmdir DVDs
    mv -i USB\ sticks/* Pictures
    rmdir USB\ sticks
    for F in Elements/* ; do
      FF=$(basename $"F")
      [ ! -e Pictures/"$FF" ] && mv "$F" Pictures
    done
    # remove empty directories...
    find . -empty -type d -delete -print
  fi
  [ ! -d "${ADDB}" ] && mkdir "${ADDB}"
}
################################################################################
JB_photos_Archive_im() {
  AD=$(dirname "${ADDB:-.}")
  find "${*}" \( \
        -iname \*.heic \
    -o  -iname \*.heiv \
    -o  -iname \*.jpg \
    -o  -iname \*.jpeg \
    -o  -iname \*.jpe \
    -o  -iname \*.png \
    -o  -iname \*.avi \
    -o  -iname \*.mov \
    -o  -iname \*.mpg \
    -o  -iname \*.mpeg \
    -o  -iname \*.mp4 \
    -o  -iname \*.m4v \
    -o  -iname \*.flv \
    -o  -iname \*.tif \
    -o  -iname \*.tiff \
    -o  -iname \*.bmp \
    -o  -iname \*.psd \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
  \) -a -type f | \
    while read file ; do
      verboseLog "\"${file}\""
      find "${AD}"/{Pictures,DVDs,Elements,USB\ sticks,makeMKV} \
        -samefile "${file}"
      [ ! -z "${vbose}" ] && imageDB_dtasi "${file}"
      [ ! -z "${vbose}" ] && imageDB_data_shasum "${file}"
    done
}
################################################################################
JB_photos_check_for_identical_data_shasums() {
  ## check the files in a .dtasi_duplicates directory for identical data_shasums
  echo "--------------------------------------------------------------------------------"
  echo "--------------------------------------------------------------------------------"
  echo "--------------------------------------------------------------------------------"
  echo "--------------------------------------------------------------------------------"
  unset _refDS
  _a_refDS=()
  _sameDS=true
  _n_ims=0
  _save_vbose=${vbose}
  truncated_images=()
  _nti=0
  _ndds=1
  ok_images=()
  _oki=0
  [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
  [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
  execCmd "mkdir -p${vbose:+v} \"${1}/.unique_data_shasums\""
  unset vbose
  for F in $(ls "${1}" | grep -v \.meta\$) ; do
    file=${1}/${F}
    _n_Archive_ims=$(JB_photos_Archive_im "${file}" | wc -l)
    if ${imageDB_rm_zero_linked_shasums:-false} && \
      [[ ${_n_Archive_ims:-1} -eq 0 ]] && \
      true ; then
      echo "\"${file}\" has no links, imageDB_rm_zero_linked_shasums=true --> removing..."
      imageDB_expung_dtasi_no_restore=$(greadlink -f "${1}")
      execCmd "imageDB_expung_dtasi \"${file}\""
      unset imageDB_expung_dtasi_no_restore
    else
      # Check for TRUNCATED images...
      (( _n_ims++ ))
      _DS=$(imageDB_data_shasum "${file}")
      if [[ $? -eq 0 ]]; then
        have_this_DS_already=false
        if [ ! -d "${1}/.unique_data_shasums/${_DS}" ]; then
          execCmd "mkdir -p${vbose:+v} \"${1}/.unique_data_shasums/${_DS}\""
          execCmd "ln -f${vbose:+v} \"${file}\" \"${1}/.unique_data_shasums/${_DS}/\""
        else
          execCmd "mkdir -p${vbose:+v} \"${1}/.duplicate_data_shasums\""
          execCmd "mv ${vbose} \"${1}/.unique_data_shasums/${_DS}\" \"${1}/.duplicate_data_shasums\""
          execCmd "ln -f${vbose:+v} \"${file}\" \"${1}/.duplicate_data_shasums/${_DS}/\""
          have_this_DS_already=true
        fi
        ! ${have_this_DS_already} && _a_refDS[${#_a_refDS[@]}]=${_DS:--1}
        [ -z "${_refDS}" ] && _refDS=${_DS:--1}
        if [ ${_DS:--1} != $_refDS ]; then
          _sameDS=false
          (( _ndds++ ))
        fi
        ok_images[$_oki]="${file}"
        (( _oki++ ))
      else
        _sameDS=false
        truncated_images[$_nti]="${file}"
        (( _nti++ ))
      fi
    fi
  done
  if [[ $_oki -eq 1 ]] && [[ $_nti -ge 1 ]]; then
    [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
    [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
    echo "\"${1}\" : One or more truncated images and one OK, relinking the truncated version(s) to the OK version..."
    _dn=$(dirname "${1}")
    _bn=$(basename "${1}")
    fix_dir=${_dn}/fix_${_bn}
    mv "${1}" "${fix_dir}"
    im_ADDB="${fix_dir}/$(basename ${ok_images[0]})"
    find "${fix_dir}" \( \
          -iname \*.heic \
      -o  -iname \*.heiv \
      -o  -iname \*.jpg \
      -o  -iname \*.jpeg \
      -o  -iname \*.jpe \
      -o  -iname \*.png \
      -o  -iname \*.avi \
      -o  -iname \*.mov \
      -o  -iname \*.mpg \
      -o  -iname \*.mpeg \
      -o  -iname \*.mp4 \
      -o  -iname \*.m4v \
      -o  -iname \*.flv \
      -o  -iname \*.tif \
      -o  -iname \*.tiff \
      -o  -iname \*.bmp \
      -o  -iname \*.psd \
      -o  -iname \*.cr2 \
      -o  -iname \*.dng \
      -o  -iname \*.gif \
      -o  -iname \*.cr2 \
      -o  -iname \*.dng \
      -o  -iname \*.gif \
    \) -a -type f | \
      while read file ; do
        if [ "$file" != "${im_ADDB}" ]; then
          execCmd "imageDB_rm_dtasi \"${file}\""
          execCmd "imageDB_relink_Archive_ims \"${file}\" \"${im_ADDB}\""
        fi
      done
    execCmd "rm -fr -v \"${fix_dir}\""
    reset_vbose
    return
  elif [[ $_oki -gt 1 ]] && [[ $_nti -ge 1 ]]; then
    [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
    [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
    echo "\"${1}\" : One or more truncated images and more than OK, not sure what to do..."
    reset_vbose
    return
  fi

  #
  if [[ ${_n_ims} -eq 0 ]]; then
    # it seems all images were removed and this dir no longer exists...
    [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
    [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
    echo "\"${1}\" : NO images left, removing this directory..."
    dtasi=$(basename "${1}")
    mkdir -p "${SHDB:-${ADDB:-.}}/.dtasi/duplicates_empty_dirs/${dtasi}"
    mv "${1}" "${SHDB:-${ADDB:-.}}/.dtasi/duplicates_empty_dirs/${dtasi}"
    reset_vbose
    return
  fi
  # 
  if [[ ${_n_ims} -eq 1 ]]; then
    # it seems all but one images were removed so this dir can be removed from duplicates...
    [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
    [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
    echo "\"${1}\" : ONE image left, restoring this directory to .dtasi..."
    dtasi=$(basename "${1}")
    mkdir -p "${SHDB:-${ADDB:-.}}/.dtasi/duplicates_restore_to_dtasi/${dtasi}"
    mv "${1}" "${SHDB:-${ADDB:-.}}/.dtasi/duplicates_restore_to_dtasi/${dtasi}"
    #if [ -d "${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}" ]; then
      #[[ $(ls "${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}" | wc -l) -eq 1 ]] && \
        #execCmd "mkdir -p \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\"" && \
        #execCmd "\mv -v \"${SHDB:-${ADDB:-.}}/.dtasi/duplicates/${dtasi}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}\""
    #fi
    reset_vbose
    return
  fi

  ## No truncated images, check now for duplicate data-shasums...
  if ${_sameDS} ; then
    [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
    [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
    all_n="all ${_n_ims}"
    [[ ${_n_ims} -eq 2 ]] && all_n="both"
    echo "\"${1}\" : ${all_n} images have the same data-shasums"
    _n_Archive_ims=$(JB_photos_Archive_im "${1}" | wc -l)
    _n_Archive_ims_P=$(JB_photos_Archive_im "${1}" | grep 'relinked/Pictures/' | wc -l)
    _n_Archive_ims_Lexar=$(JB_photos_Archive_im "${1}" | grep 'relinked/Elements/Lexar/' | wc -l)
    _n_Archive_ims_Fiji=$(JB_photos_Archive_im "${1}" | grep 'Elements/2012-04-14 Fiji' | wc -l)
    _n_Archive_ims_2013_08_04_Holiday=$(JB_photos_Archive_im "${1}" | grep '/Elements/2013-08-04 Holiday' | wc -l)
    _n_Archive_ims_2013_01_02_001=$(JB_photos_Archive_im "${1}" | grep '/Pictures/2013-01-02 001' | wc -l)
    _n_Archive_ims_2012_12_30_001=$(JB_photos_Archive_im "${1}" | grep '/Pictures/2012-12-30 001' | wc -l)
    _n_Archive_ims_2016_02_02_001=$(JB_photos_Archive_im "${1}" | grep '/Elements/2016-02-02 001' | wc -l)
    _n_Archive_ims_xmas_2012=$(JB_photos_Archive_im "${1}" | grep '/Elements/xmas 2012/DCIM/101_PANA' | wc -l)
    if [ -d "${1}" ] && \
      [[ ${_n_Archive_ims} -ge 2 ]] && \
      [[ ${_n_Archive_ims_P} -eq 1 ]] && \
      true ; then
      im_P=$(JB_photos_Archive_im "${1}" | grep 'relinked/Pictures/' | head -n 1)
      im_nP=$(JB_photos_Archive_im "${1}" | grep -v 'relinked/Pictures/' | gsed -e 's% %_@_%g')
      if ${relink_duplicates:-false} ; then
        echo "One image in Pictures and one or more not-in-Pictures, relinking the not-in-Pictures versions to the Pictures version..."
      else
        echo "One image in Pictures and one or more not-in-Pictures, rm the not-in-Pictures version(s)..."
      fi
      find "${1}" \( \
            -iname \*.heic \
        -o  -iname \*.heiv \
        -o  -iname \*.jpg \
        -o  -iname \*.jpeg \
        -o  -iname \*.jpe \
        -o  -iname \*.png \
        -o  -iname \*.avi \
        -o  -iname \*.mov \
        -o  -iname \*.mpg \
        -o  -iname \*.mpeg \
        -o  -iname \*.mp4 \
        -o  -iname \*.m4v \
        -o  -iname \*.flv \
        -o  -iname \*.tif \
        -o  -iname \*.tiff \
        -o  -iname \*.bmp \
        -o  -iname \*.psd \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
      \) -a -type f | \
        while read file ; do
          execCmd "imageDB_rm_dtasi \"${file}\""
        done
      execCmd "rm -fr -v \"${1}\""
      if ${relink_duplicates:-false} ; then
        for file in ${im_nP} ; do
          execCmd "imageDB_relink_Archive_ims \"${file//_@_/ }\" \"${im_P}\""
        done
      else
        for file in ${im_nP} ; do
          execCmd "rm -fv \"${file//_@_/ }\""
        done
        execCmd "imageDB_shasum_dtasi_links \"${im_P}\""
      fi
    elif [ -d "${1}" ] && \
      [[ ${_n_Archive_ims} -eq 2 ]] && \
      [[ ${_n_Archive_ims_Lexar} -eq 1 ]] && \
      true ; then
      im_L=$(JB_photos_Archive_im "${1}" | grep 'relinked/Elements/Lexar/' | head -n 1 | gsed -e 's% %_@_%g')
      im_nL=$(JB_photos_Archive_im "${1}" | grep -v 'relinked/Elements/Lexar/' | gsed -e 's% %_@_%g')
      if ${relink_duplicates:-false} ; then
        echo "One image in Lexar and one not-in-Lexar, relinking the Lexar version to the not-in-Lexar version..."
      else
        echo "One image in Lexar and one not-in-Lexar, rm the Lexar version(s)..."
      fi
      find "${1}" \( \
            -iname \*.heic \
        -o  -iname \*.heiv \
        -o  -iname \*.jpg \
        -o  -iname \*.jpeg \
        -o  -iname \*.jpe \
        -o  -iname \*.png \
        -o  -iname \*.avi \
        -o  -iname \*.mov \
        -o  -iname \*.mpg \
        -o  -iname \*.mpeg \
        -o  -iname \*.mp4 \
        -o  -iname \*.m4v \
        -o  -iname \*.flv \
        -o  -iname \*.tif \
        -o  -iname \*.tiff \
        -o  -iname \*.bmp \
        -o  -iname \*.psd \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
      \) -a -type f | \
        while read file ; do
          execCmd "imageDB_rm_dtasi \"${file}\""
        done
      execCmd "rm -fr -v \"${1}\""
      if ${relink_duplicates:-false} ; then
        execCmd "imageDB_relink_Archive_ims \"${im_L//_@_/ }\" \"${im_nL//_@_/ }\""
      else
        execCmd "rm -fv \"${im_L//_@_/ }\""
        execCmd "imageDB_shasum_dtasi_links \"${im_nL//_@_/ }\""
      fi
    elif [ -d "${1}" ] && \
      [[ ${_n_Archive_ims} -ge 2 ]] && \
      [[ ${_n_Archive_ims_Fiji} -eq 1 ]] && \
      true ; then
      im_F=$(JB_photos_Archive_im "${1}" | grep 'Elements/2012-04-14 Fiji' | head -n 1 | gsed -e 's% %_@_%g')
      im_nF=$(JB_photos_Archive_im "${1}" | grep -v 'Elements/2012-04-14 Fiji' | gsed -e 's% %_@_%g')
      if ${relink_duplicates:-false} ; then
        echo "One image in Fiji and one not-in-Fiji, relinking the not-in-Fiji version to the Fiji version..."
      else
        echo "One image in Fiji and one not-in-Fiji, rm the not-in-Fiji version(s)..."
      fi
      find "${1}" \( \
            -iname \*.heic \
        -o  -iname \*.heiv \
        -o  -iname \*.jpg \
        -o  -iname \*.jpeg \
        -o  -iname \*.jpe \
        -o  -iname \*.png \
        -o  -iname \*.avi \
        -o  -iname \*.mov \
        -o  -iname \*.mpg \
        -o  -iname \*.mpeg \
        -o  -iname \*.mp4 \
        -o  -iname \*.m4v \
        -o  -iname \*.flv \
        -o  -iname \*.tif \
        -o  -iname \*.tiff \
        -o  -iname \*.bmp \
        -o  -iname \*.psd \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
      \) -a -type f | \
        while read file ; do
          execCmd "imageDB_rm_dtasi \"${file}\""
        done
      execCmd "rm -fr -v \"${1}\""
      if ${relink_duplicates:-false} ; then
        for file in ${im_nF} ; do
          execCmd "imageDB_relink_Archive_ims \"${file//_@_/ }\" \"${im_F//_@_/ }\""
        done
      else
        for file in ${im_nF} ; do
          execCmd "rm -fv \"${file//_@_/ }\""
        done
        execCmd "imageDB_shasum_dtasi_links \"${im_F//_@_/ }\""
      fi
    elif [ -d "${1}" ] && \
      [[ ${_n_Archive_ims} -ge 2 ]] && \
      [[ ${_n_Archive_ims_2013_08_04_Holiday} -eq 1 ]] && \
      true ; then
      im_F=$(JB_photos_Archive_im "${1}" | grep '/Elements/2013-08-04 Holiday' | head -n 1 | gsed -e 's% %_@_%g')
      im_nF=$(JB_photos_Archive_im "${1}" | grep -v '/Elements/2013-08-04 Holiday' | gsed -e 's% %_@_%g')
      if ${relink_duplicates:-false} ; then
        echo "One image in 2013-08-04 Holiday and one not-in-2013-08-04 Holiday, relinking the not-in-2013-08-04 Holiday version to the 2013-08-04 Holiday version..."
      else
        echo "One image in 2013-08-04 Holiday and one not-in-2013-08-04 Holiday, rm the not-in-2013-08-04 Holiday version(s)..."
      fi
      find "${1}" \( \
            -iname \*.heic \
        -o  -iname \*.heiv \
        -o  -iname \*.jpg \
        -o  -iname \*.jpeg \
        -o  -iname \*.jpe \
        -o  -iname \*.png \
        -o  -iname \*.avi \
        -o  -iname \*.mov \
        -o  -iname \*.mpg \
        -o  -iname \*.mpeg \
        -o  -iname \*.mp4 \
        -o  -iname \*.m4v \
        -o  -iname \*.flv \
        -o  -iname \*.tif \
        -o  -iname \*.tiff \
        -o  -iname \*.bmp \
        -o  -iname \*.psd \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
      \) -a -type f | \
        while read file ; do
          execCmd "imageDB_rm_dtasi \"${file}\""
        done
      execCmd "rm -fr -v \"${1}\""
      if ${relink_duplicates:-false} ; then
        for file in ${im_nF} ; do
          execCmd "imageDB_relink_Archive_ims \"${file//_@_/ }\" \"${im_F//_@_/ }\""
        done
      else
        for file in ${im_nF} ; do
          execCmd "rm -fv \"${file//_@_/ }\""
        done
        execCmd "imageDB_shasum_dtasi_links \"${im_F//_@_/ }\""
      fi
    elif [ -d "${1}" ] && \
      [[ ${_n_Archive_ims} -ge 2 ]] && \
      [[ ${_n_Archive_ims_2013_01_02_001} -eq 1 ]] && \
      true ; then
      im_F=$(JB_photos_Archive_im "${1}" | grep '/Pictures/2013-01-02 001' | head -n 1 | gsed -e 's% %_@_%g')
      im_nF=$(JB_photos_Archive_im "${1}" | grep -v '/Pictures/2013-01-02 001' | gsed -e 's% %_@_%g')
      if ${relink_duplicates:-false} ; then
        echo "One image in /Pictures/2013-01-02 001 and one not-in-/Pictures/2013-01-02 001, relinking the not-in-/Pictures/2013-01-02 001 version to the /Pictures/2013-01-02 001 version..."
      else
        echo "One image in /Pictures/2013-01-02 001 and one not-in-/Pictures/2013-01-02 001, rm the not-in-/Pictures/2013-01-02 001 version(s)..."
      fi
      find "${1}" \( \
            -iname \*.heic \
        -o  -iname \*.heiv \
        -o  -iname \*.jpg \
        -o  -iname \*.jpeg \
        -o  -iname \*.jpe \
        -o  -iname \*.png \
        -o  -iname \*.avi \
        -o  -iname \*.mov \
        -o  -iname \*.mpg \
        -o  -iname \*.mpeg \
        -o  -iname \*.mp4 \
        -o  -iname \*.m4v \
        -o  -iname \*.flv \
        -o  -iname \*.tif \
        -o  -iname \*.tiff \
        -o  -iname \*.bmp \
        -o  -iname \*.psd \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
      \) -a -type f | \
        while read file ; do
          execCmd "imageDB_rm_dtasi \"${file}\""
        done
      execCmd "rm -fr -v \"${1}\""
      if ${relink_duplicates:-false} ; then
        for file in ${im_nF} ; do
          execCmd "imageDB_relink_Archive_ims \"${file//_@_/ }\" \"${im_F//_@_/ }\""
        done
      else
        for file in ${im_nF} ; do
          execCmd "rm -fv \"${file//_@_/ }\""
        done
        execCmd "imageDB_shasum_dtasi_links \"${im_F//_@_/ }\""
      fi
    elif [ -d "${1}" ] && \
      [[ ${_n_Archive_ims} -ge 2 ]] && \
      [[ ${_n_Archive_ims_2012_12_30_001} -eq 1 ]] && \
      true ; then
      im_F=$(JB_photos_Archive_im "${1}" | grep '/Pictures/2012-12-30 001' | head -n 1 | gsed -e 's% %_@_%g')
      im_nF=$(JB_photos_Archive_im "${1}" | grep -v '/Pictures/2012-12-30 001' | gsed -e 's% %_@_%g')
      if ${relink_duplicates:-false} ; then
        echo "One image in /Pictures/2012-12-30 001 and one not-in-/Pictures/2012-12-30 001, relinking the not-in-/Pictures/2012-12-30 001 version to the /Pictures/2012-12-30 001 version..."
      else
        echo "One image in /Pictures/2012-12-30 001 and one not-in-/Pictures/2012-12-30 001, rm the not-in-/Pictures/2012-12-30 001 version(s)..."
      fi
      find "${1}" \( \
            -iname \*.heic \
        -o  -iname \*.heiv \
        -o  -iname \*.jpg \
        -o  -iname \*.jpeg \
        -o  -iname \*.jpe \
        -o  -iname \*.png \
        -o  -iname \*.avi \
        -o  -iname \*.mov \
        -o  -iname \*.mpg \
        -o  -iname \*.mpeg \
        -o  -iname \*.mp4 \
        -o  -iname \*.m4v \
        -o  -iname \*.flv \
        -o  -iname \*.tif \
        -o  -iname \*.tiff \
        -o  -iname \*.bmp \
        -o  -iname \*.psd \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
      \) -a -type f | \
        while read file ; do
          execCmd "imageDB_rm_dtasi \"${file}\""
        done
      execCmd "rm -fr -v \"${1}\""
      if ${relink_duplicates:-false} ; then
        for file in ${im_nF} ; do
          execCmd "imageDB_relink_Archive_ims \"${file//_@_/ }\" \"${im_F//_@_/ }\""
        done
      else
        for file in ${im_nF} ; do
          execCmd "rm -fv \"${file//_@_/ }\""
        done
        execCmd "imageDB_shasum_dtasi_links \"${im_F//_@_/ }\""
      fi
    elif [ -d "${1}" ] && \
      [[ ${_n_Archive_ims} -ge 2 ]] && \
      [[ ${_n_Archive_ims_2016_02_02_001} -eq 1 ]] && \
      true ; then
      im_F=$(JB_photos_Archive_im "${1}" | grep '/Elements/2016-02-02 001' | head -n 1 | gsed -e 's% %_@_%g')
      im_nF=$(JB_photos_Archive_im "${1}" | grep -v '/Elements/2016-02-02 001' | gsed -e 's% %_@_%g')
      if ${relink_duplicates:-false} ; then
        echo "One image in /Elements/2016-02-02 001 and one not-in-/Elements/2016-02-02 001, relinking the not-in-/Elements/2016-02-02 001 version to the /Elements/2016-02-02 001 version..."
      else
        echo "One image in /Elements/2016-02-02 001 and one not-in-/Elements/2016-02-02 001, rm the not-in-/Elements/2016-02-02 001 version(s)..."
      fi
      find "${1}" \( \
            -iname \*.heic \
        -o  -iname \*.heiv \
        -o  -iname \*.jpg \
        -o  -iname \*.jpeg \
        -o  -iname \*.jpe \
        -o  -iname \*.png \
        -o  -iname \*.avi \
        -o  -iname \*.mov \
        -o  -iname \*.mpg \
        -o  -iname \*.mpeg \
        -o  -iname \*.mp4 \
        -o  -iname \*.m4v \
        -o  -iname \*.flv \
        -o  -iname \*.tif \
        -o  -iname \*.tiff \
        -o  -iname \*.bmp \
        -o  -iname \*.psd \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
      \) -a -type f | \
        while read file ; do
          execCmd "imageDB_rm_dtasi \"${file}\""
        done
      execCmd "rm -fr -v \"${1}\""
      if ${relink_duplicates:-false} ; then
        for file in ${im_nF} ; do
          execCmd "imageDB_relink_Archive_ims \"${file//_@_/ }\" \"${im_F//_@_/ }\""
        done
      else
        for file in ${im_nF} ; do
          execCmd "rm -fv \"${file//_@_/ }\""
        done
        execCmd "imageDB_shasum_dtasi_links \"${im_F//_@_/ }\""
      fi
    elif [ -d "${1}" ] && \
      [[ ${_n_Archive_ims} -ge 2 ]] && \
      [[ ${_n_Archive_ims_xmas_2012} -eq 1 ]] && \
      true ; then
      im_F=$(JB_photos_Archive_im "${1}" | grep '/Elements/xmas 2012/DCIM/101_PANA' | head -n 1 | gsed -e 's% %_@_%g')
      im_nF=$(JB_photos_Archive_im "${1}" | grep -v '/Elements/xmas 2012/DCIM/101_PANA' | gsed -e 's% %_@_%g')
      if ${relink_duplicates:-false} ; then
        echo "One image in xmas_2012 and one not-in-xmas_2012, relinking the not-in-xmas_2012 version to the xmas_2012 version..."
      else
        echo "One image in xmas_2012 and one not-in-xmas_2012, rm the not-in-xmas_2012 version(s)..."
      fi
      find "${1}" \( \
            -iname \*.heic \
        -o  -iname \*.heiv \
        -o  -iname \*.jpg \
        -o  -iname \*.jpeg \
        -o  -iname \*.jpe \
        -o  -iname \*.png \
        -o  -iname \*.avi \
        -o  -iname \*.mov \
        -o  -iname \*.mpg \
        -o  -iname \*.mpeg \
        -o  -iname \*.mp4 \
        -o  -iname \*.m4v \
        -o  -iname \*.flv \
        -o  -iname \*.tif \
        -o  -iname \*.tiff \
        -o  -iname \*.bmp \
        -o  -iname \*.psd \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
        -o  -iname \*.cr2 \
        -o  -iname \*.dng \
        -o  -iname \*.gif \
      \) -a -type f | \
        while read file ; do
          execCmd "imageDB_rm_dtasi \"${file}\""
        done
      execCmd "rm -fr -v \"${1}\""
      if ${relink_duplicates:-false} ; then
        for file in ${im_nF} ; do
          execCmd "imageDB_relink_Archive_ims \"${file//_@_/ }\" \"${im_F//_@_/ }\""
        done
      else
        for file in ${im_nF} ; do
          execCmd "rm -fv \"${file//_@_/ }\""
        done
        execCmd "imageDB_shasum_dtasi_links \"${im_F//_@_/ }\""
      fi
    elif [ -d "${1}" ] && \
      [[ ${_n_Archive_ims} -eq 2 ]] && \
      [[ -e CFIDS.sort-rn ]] && \
      true ; then
      CFIDS_mv=true
      for CFIDS_D in $(awk '{print $2}' CFIDS\.sort-rn) ; do
        if $CFIDS_mv ; then
          im_F=$(JB_photos_Archive_im "${1}"  | sed -e 's@\(^.*/\).*@\1@' | grep    "^${CFIDS_D//_%_/ }\$" | head -n 1 | gsed -e 's% %_@_%g')
          im_nF=$(JB_photos_Archive_im "${1}" | sed -e 's@\(^.*/\).*@\1@' | grep -v "^${CFIDS_D//_%_/ }\$" | gsed -e 's% %_@_%g')
          if [ ! -z "${im_F}" ] && [ ! -z "${im_nF}" ]; then
            CFIDS_mv=false
            im_F=$(JB_photos_Archive_im "${1}"  | grep    "${CFIDS_D//_%_/ }" | head -n 1 | gsed -e 's% %_@_%g')
            im_nF=$(JB_photos_Archive_im "${1}" | grep -v "${CFIDS_D//_%_/ }" | gsed -e 's% %_@_%g')
            if ${relink_duplicates:-false} ; then
              echo "One image in ${CFIDS_D//_%_/ } and one not-in-${CFIDS_D//_%_/ }, relinking the not-in-${CFIDS_D//_%_/ } version to the ${CFIDS_D//_%_/ } version..."
            else
              echo "One image in ${CFIDS_D//_%_/ } and one not-in-${CFIDS_D//_%_/ }, rm the not-in-${CFIDS_D//_%_/ } version(s)..."
            fi
            find "${1}" \( \
                  -iname \*.heic \
              -o  -iname \*.heiv \
              -o  -iname \*.jpg \
              -o  -iname \*.jpeg \
              -o  -iname \*.jpe \
              -o  -iname \*.png \
              -o  -iname \*.avi \
              -o  -iname \*.mov \
              -o  -iname \*.mpg \
              -o  -iname \*.mpeg \
              -o  -iname \*.mp4 \
              -o  -iname \*.m4v \
              -o  -iname \*.flv \
              -o  -iname \*.tif \
              -o  -iname \*.tiff \
              -o  -iname \*.bmp \
              -o  -iname \*.psd \
              -o  -iname \*.cr2 \
              -o  -iname \*.dng \
              -o  -iname \*.gif \
              -o  -iname \*.cr2 \
              -o  -iname \*.dng \
              -o  -iname \*.gif \
            \) -a -type f | \
              while read file ; do
                execCmd "imageDB_rm_dtasi \"${file}\""
              done
            execCmd "rm -fr -v \"${1}\""
            if ${relink_duplicates:-false} ; then
              for file in ${im_nF} ; do
                execCmd "imageDB_relink_Archive_ims \"${file//_@_/ }\" \"${im_F//_@_/ }\""
              done
            else
              for file in ${im_nF} ; do
                execCmd "rm -fv \"${file//_@_/ }\""
              done
              execCmd "imageDB_shasum_dtasi_links \"${im_F//_@_/ }\""
            fi
          elif [ ! -z "${im_F}" ] && [ -z "${im_nF}" ]; then
            CFIDS_mv=false
            im_F=$(JB_photos_Archive_im "${1}"  | grep    "${CFIDS_D//_%_/ }" | head -n 1 | sed -e 's% %_@_%g')
            im_nF=$(JB_photos_Archive_im "${1}" | grep -v "${CFIDS_D//_%_/ }" | sed -e 's% %_@_%g')
            echo "Both images in the same directory..."
            echo "SameDir = ${CFIDS_D//_%_/ }"
            JB_photos_Archive_im "${1}"
            echo "Keeping the one with more (hopefully better) meta-data..."
            JB_photos_meta "${1}"
            keep_shasum=$(ls -S "${1}"/.*.meta | head -n 1 | sed -e 's@^.*/.@@' -e 's@.meta$@@')
            echo "keep_shasum = $keep_shasum"
            im_F=$(JB_photos_Archive_im "${1}"/${keep_shasum} | sed -e 's% %_@_%g')
            echo "Keeping ${im_F}"
            find "${1}" \( \
                  -iname \*.heic \
              -o  -iname \*.heiv \
              -o  -iname \*.jpg \
              -o  -iname \*.jpeg \
              -o  -iname \*.jpe \
              -o  -iname \*.png \
              -o  -iname \*.avi \
              -o  -iname \*.mov \
              -o  -iname \*.mpg \
              -o  -iname \*.mpeg \
              -o  -iname \*.mp4 \
              -o  -iname \*.m4v \
              -o  -iname \*.flv \
              -o  -iname \*.tif \
              -o  -iname \*.tiff \
              -o  -iname \*.bmp \
              -o  -iname \*.psd \
              -o  -iname \*.cr2 \
              -o  -iname \*.dng \
              -o  -iname \*.gif \
              -o  -iname \*.cr2 \
              -o  -iname \*.dng \
              -o  -iname \*.gif \
            \) -a -type f | \
              while read file ; do
                echo file=$file
                bnfile=$(basename "${file}")
                echo bnfile=$bnfile
                if [ "${bnfile}" != "${keep_shasum}" ]; then
                  echo "Adding $file"
                  im_nF=$(JB_photos_Archive_im "${file}" | sed -e 's% %_@_%g')
                  if ${relink_duplicates:-false} ; then
                    execCmd "imageDB_relink_Archive_ims \"${im_nF//_@_/ }\" \"${im_F//_@_/ }\""
                  else
                    execCmd "rm -fv \"${im_nF//_@_/ }\""
                  fi
                fi
                execCmd "imageDB_rm_dtasi \"${file}\""
              done

            execCmd "rm -fr -v \"${1}\""
            if ! ${relink_duplicates:-false} ; then
              execCmd "imageDB_shasum_dtasi_links \"${im_F//_@_/ }\""
            fi
          fi
        fi
      done
    else
      if [[ ${_n_ims} -eq 2 ]]; then
        JB_photos_Archive_im "${1}"
      fi
      if [[ ${_n_ims} -gt 2 ]]; then
        JB_photos_Archive_im "${1}"
      fi
    fi
  else
    if [[ ${_n_ims} -eq 2 ]]; then
      [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
      [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
      _n_Archive_ims=$(JB_photos_Archive_im "${1}" | wc -l)
      _n_Archive_ims_P=$(JB_photos_Archive_im "${1}" | grep 'Pictures' | wc -l)
      if [ -d "${1}" ] && \
        true ; then
        echo "\"${1}\" : ${_n_ims} shasum images == ${#_a_refDS[@]} different data-shasums values, keeping all..."
        execCmd "imageDB_keep_remaining_dup_dtasis_all_unique_shasums \"${1}\""
        JB_photos_Archive_im "${1}"
      fi
    elif [ -d "${1}" ] && \
      true ; then
      if [[ ${_n_ims} -eq ${#_a_refDS[@]} ]]; then
        echo "\"${1}\" : ${_n_ims} shasum == ${#_a_refDS[@]} different data-shasums values, keeping all..."
        [ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
        [ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
        execCmd "imageDB_keep_remaining_dup_dtasis_all_unique_shasums \"${1}\""
        JB_photos_Archive_im "${1}"
      else
        echo "\"${1}\" : ${_n_ims} shasum images/${#_a_refDS[@]} different data-shasums values, moving unique data-shasums out of duplicates..."
        for F in $(ls "${1}"/.unique_data_shasums/*/* 2>/dev/null) ; do
          dtasi=$(imageDB_dtasi "${F}")
          execCmd "mkdir -p${vbose:+v} \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}\""
          bnF=$(basename "${F}")
          execCmd "mv ${vbose:+v} \"${1}/${bnF}\" \"${SHDB:-${ADDB:-.}}/.dtasi/${dtasi:0:7}/${dtasi}\""
        done
        JB_photos_Archive_im "${1}"
      fi
    fi
  fi
  #[ -d "${1}/.unique_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.unique_data_shasums\""
  #[ -d "${1}/.duplicate_data_shasums" ] && execCmd "rm -fr${vbose:+v} \"${1}/.duplicate_data_shasums\""
  reset_vbose
}
################################################################################
JB_photos_meta() {
  find "${1}" \( \
        -iname \*.heic \
    -o  -iname \*.heiv \
    -o  -iname \*.jpg \
    -o  -iname \*.jpeg \
    -o  -iname \*.jpe \
    -o  -iname \*.png \
    -o  -iname \*.avi \
    -o  -iname \*.mov \
    -o  -iname \*.mpg \
    -o  -iname \*.mpeg \
    -o  -iname \*.mp4 \
    -o  -iname \*.m4v \
    -o  -iname \*.flv \
    -o  -iname \*.tif \
    -o  -iname \*.tiff \
    -o  -iname \*.bmp \
    -o  -iname \*.psd \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
    -o  -iname \*.cr2 \
    -o  -iname \*.dng \
    -o  -iname \*.gif \
  \) -a -type f | \
    while read file ; do
      _mf=$(dirname "${file}")/.$(basename "${file}").meta
      JB_photos_Archive_im "${file}"     >"${_mf}"
      exiftool -s -a "${file}" | sort >>"${_mf}"
    done
}
################################################################################
JB_photos_scans_set_datetimeoriginal() {
  cd /Volumes/JB_Elements/Archive/JB/Scans
  # Setting GPSdatetime should 
  geolocation_LambsLane=$(vjpd_geolocate_photos.py -l "Lambs Lane, Padgate, Warrington, England")
  geolocation_LambsLane=$(vjpd_geolocate_photos.py -l "KeriKeri, New Zealand")
  exiftool -v0 \
    -datetimeoriginal="1962:03:25 12:00:00" \
    -GPSdatestamp="1962:03:25 11:00:00" \
    -GPStimestamp="1962:03:25 11:00:00" \
    ${geolocation_LambsLane} \
    -overwrite_original_in_place -preserve \
    -fileOrder filename \
    -r w1
    #JB\ wedding\ album
  exiftool -v0 \
    '-datetimeoriginal+<0:$filesequence' \
    '-GPStimestamp+<0:$filesequence' \
    -overwrite_original_in_place -preserve \
    -fileOrder filename \
    -r w1
    #JB\ wedding\ album
}
################################################################################
## Mistakes
# /Volumes/LaCie Disk/Archive/imageDB/Our Pictures/Family/Mamie&Papi/Papa Photos 11-2012/Mes images 1/Cliff in Clouds.jpg relinked to and ADDB image in error
################################################################################
################################################################################
################################################################################
JF_mk_links_set_lang_dir() {
  lang_dir=$(
    echo ${1} | sed \
      -e 's@.*/fra/.*@fra@' \
      -e 's@.*/deu/.*@deu@' \
      -e 's@.*/ita/.*@ita@' \
      -e 's@.*/.*@eng@'
  )
}
################################################################################
