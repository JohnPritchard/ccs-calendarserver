#!/bin/sh

## "@(#) $Id: macOSX.Apple_ccs_to_vjpd_ccs_migration 3991 2022-03-14 10:07:32Z vdoublie $"

################################################################################
## Definition of functions
usage() {
  printf "\
Usage: ${execName} [-h|Dvnq]

  -h|--help: help
  -D|--debug: debug
  -n|--dryRun: dry-run
  -q|--quiet: quiet
     -q Only Warnings and Errors are written out (to stderr)
     -q -q increases quietness, only Errors are written out (to stderr)
     -q -q -q increases quietness, NO output to stdout or stderr
  -v|--verbose: verbose

  -H|--hostname  <hostname>: default '/bin/hostname -s'

"
  exit ${exstat:-0}
}

################################################################################
## Definition of variable who need default values
execName="`basename ${0}`"
quietLevel=0
_hostname_s=$(/bin/hostname -s)

################################################################################
## Generic utility functions
if [ -d /opt/local/bin ]; then
  export PATH=/opt/local/bin:${PATH}
fi
if [ -z "${VJPD_FUNCTIONS_READLINK}" ]; then
  VJPD_FUNCTIONS_READLINK="readlink"
  which greadlink > /dev/null 2>&1 && VJPD_FUNCTIONS_READLINK="greadlink"
  if ! ${VJPD_FUNCTIONS_READLINK} -f ${0} >/dev/null 2>&1 ; then
    echo "${VJPD_FUNCTIONS_READLINK} does not support -f command line option"
    exit 1
  fi
fi
[ -z "${VJPD_FUNCTIONS}" ] && VJPD_FUNCTIONS="$(ls $(dirname $(${VJPD_FUNCTIONS_READLINK} -f ${0}))/vjpd.functions.sh 2>/dev/null)"
if [ -e ${VJPD_FUNCTIONS:-/opt/vjpd/bin/vjpd.functions.sh} ]; then
  . ${VJPD_FUNCTIONS:-/opt/vjpd/bin/vjpd.functions.sh}
else
  echo "${execName}::Error:: ${VJPD_FUNCTIONS:-/opt/vjpd/bin/vjpd.functions.sh} does NOT exist"
  exit 1
fi
# ------------------------------------------------------------------------------

################################################################################
## Command line options
while [ ! -z "${1}" ]; do

  case $1 in
    -h|--help)     usage ; shift;;
    -D|--debug)    debug="-D"; quiet=""; vbose="-v";  quietLevel=0 ; shift;;
    -n|--dryRun)   dryRun="-n"; shift;;
    -q|--quiet)    quiet="${quiet} -q"; vbose=""; debug=""; (( quietLevel++ )) ; shift;;
    -v|--verbose)  vbose="-v"; quiet="";  quietLevel=0 ; shift;;

    -H|--hostname) _hostname_s="${2}"; shift; shift;;
    *)             exstat=1; usage; shift;;
  esac
done

_cen=$(greadlink -f "${0}")
source $(dirname "${_cen}")/macOSX.calendar_utils.sh
################################################################################
## Main loop starts...

exstat=0

# Call other template.bash based scripts with command line options:
##  ${quiet} ${dryRun} ${debug} ${vbose}
# or
##  ${quiet} ${dryRun} ${debug:+-d} ${vbose}
# for older scripts with "-d" for debug rather than -D

##########################################################################################################

# Shutdown running calendar server...
execCmd "sudo launchctl unload -w /Library/LaunchDaemons/org.calendarserver.plist"
# Create new certificates...
execCmdIgnoreDryRun "create_self_signed_certs"
# restart calendar server...
execCmd "sudo launchctl load -w /Library/LaunchDaemons/org.calendarserver.plist"

exit
