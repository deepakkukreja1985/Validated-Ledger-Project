#!/bin/bash

###############################################################################
# Script Name         : validated_ledger.sh
# Desicription        : This shell script periodically calls server info
#                       command and records the sequence number of the latest
#                       validated ledger along with the current time. This 
#                       data is then recorded in a file and then used to 
#                       construct a plot time on X axis and sequence number
#                       on y axis and age (time taken by server to validate 
#                       ledger) of the each iteration on x2 axis.
# Author              : Deepak Kukreja
# Date                : 2020/05/25
# Revision History    : 0.1
###############################################################################

# Get Script Name and Version
PROGNAME=${0##*/}
SCRIPT_NAME=`basename $0 | sed -e 's/.sh$//'`
SCRIPT_VERSION='0.1'

# Get Date String
SCRIPT_DATE=`date '+%F_%H:%M:%S'`

# Get user's real name and email address
AUTHOR=`whoami`
FAMILYNAME='kukreja'
YEAROFBIRTH='1985'
EMAIL_ADDRESS=`whoami`"${FAMILYNAME}""$YEAROFBIRTH"'@gmail.com'

# Path Variables
BASE_DIR=`pwd`
CNF_DIR=$BASE_DIR/etc
LOG_DIR=$BASE_DIR/log
OUTPUT_DIR=$BASE_DIR/output
SCRIPT_DIR=$BASE_DIR/scripts
CNF_FILE="${CNF_DIR}/validated_ledger.conf"
PLOT_DATAFILE="${CNF_DIR}/plot.dat"
LOG_FILE="${LOG_DIR}/log.txt"
PLOT_FILE="${OUTPUT_DIR}/plot.csv"
OUTPUT_FILE="${OUTPUT_DIR}/output.txt"

# Default Config Values
URL="http://s1.ripple.com:51234/"
COMMAND="server_info"
MAX_REDIRECT=1
DOWN_TIME_PERIOD=10
POLLING_COUNT=20
SAMPLE_COUNT=10

# Variables
starttime=0  # Timestamp of first validated ledger
mintime=0    # Minimum time for a ledger to get validated in the given time interval
maxtime=0    # Maximum time for a ledger to get validated in the given time interval

startseq=0   # Sequence of the first validated ledger in the polling sample
prevseq=0    # Sequence of the last validated ledger in the polling sample
newseq=0
newtime=0
age=0;
poll_interval=0
_closed_count=0

# HTTP Exit Codes
HTTP_OK=200
HTTP_MOVED_PERMANENTLY=301
HTTP_BAD_REQUEST=400
HTTP_FORBIDDEN=403
HTTP_SERVICE_UNAVAILABLE=504

# Exit Codes
STATUS_OK="success"
STATUS_ERR="error"
declare -r TRUE=0
declare -r FALSE=1

###########################################################
# Read a config file and update script variable.
# CONFIG_SERVER_URL     : Ripple Server URL
# CONFIG_SERVER_COMMAND : server_info
# CONFIG_MAX_REDIRECT   : Redirect count in case of proxy
# CONFIG_SERVER_DOWN_TIME_PERIOD : No of times the script 
#                        will check if server available
# CONFIG_SERVER_POLLING_COUNT : 
# timespan = CONFIG_SERVER_POLLING_COUNT * Polling interval 
# No of times server info will be called to get validated
# ledgers and timestamp
# CONFIG_SERVER_SAMPLE_COUNT : Sample count use to calculate
#                              Polling interval
# Arguments:
#   None
# Returns:
#   None
#########################################################
function read_cfg_file () {

source $CNF_FILE
CFG_URL=$CONFIG_SERVER_URL
CFG_COMMAND=$CONFIG_SERVER_COMMAND
CFG_MAX_REDIRECT=$CONFIG_MAX_REDIRECT
CFG_CHK_SERVER_CNT=$CONFIG_SERVER_DOWN_TIME_PERIOD
CFG_POLLING_CNT=$CONFIG_SERVER_POLLING_COUNT
CFG_SAMPLE_CNT=$CONFIG_SERVER_SAMPLE_COUNT

}

###########################################################
# Perform pre-exit housekeeping
# Arguments:
#   None
# Returns:
#   None
#########################################################

error_exit() {
  echo -e "${PROGNAME}: ${1:- "Unknown Error"}" &>> $LOG_FILE
  exit $FALSE
}

###########################################################
# Perform pre-exit housekeeping
# Arguments:
#   None
# Returns:
#   None
#########################################################

# Perform pre-exit housekeeping
graceful_exit() {
  exit $TRUE
}

###########################################################
# Plot the graph by using plot.csv file
# Graph setting in plot.dat file.
# Arguments:
#   None
# Returns:
#   None
#########################################################

function plot_graph () {
  local _ret=${TRUE};

  echo "Plot Graph" &>> $LOG_FILE

  # execute gnuplut to plot the graph. 
  # plot.dat file contains setting for the graph
  # -p means persist mode
  gnuplot -p "$PLOT_DATAFILE"
  _ret=$?

  return $_ret;
}

###########################################################
# Calculate average timestamp for timespan 
# mintime,maxtime,average time copied output.txt file
# Arguments:
#   None
# Returns:
#   True for Success
#   False for Failure
#########################################################

function cal_avg_timestamp () {
  local _totvalidated=0;
  local _avgtime=0;
  local _tdiff=0;

  # count of total validated ledger
  _totvalidated=$(expr ${newseq} - ${startseq})

  # calculating time difference between start and end time
  _tdiff=`(echo "$(( $(date -d "${newtime}" '+%s') - $(date -d "${starttime}" '+%s') ))")`

  # average time difference between start and end time
  _avgtime=$(($_tdiff/$_totvalidated))

  echo Start Time=$starttime > $OUTPUT_FILE
  echo End Time=$newtime >> $OUTPUT_FILE
  echo Start Sequence=$startseq >> $OUTPUT_FILE
  echo End Sequence=$newseq >> $OUTPUT_FILE
  echo End Sequence=$newseq >> $OUTPUT_FILE
  echo Closed Ledger Count=$_closed_count >> $OUTPUT_FILE
  echo Polling Interval=$poll_interval sec >> $OUTPUT_FILE
  echo Minimum Time Taken by Ledger to get Validated=$mintime >> $OUTPUT_FILE
  echo Maximum Time Taken by Ledger to get Validated=$maxtime >> $OUTPUT_FILE
  echo Average Time Taken by Ledger to get Validated=$_avgtime >> $OUTPUT_FILE
}

###########################################################
# Calculate time to get a validated ledger and write to 
# plot file
# Arguments:
#  http output of curl command is passed
# Returns:
#  None
#########################################################

function calculate_age() {
  local _data=$1

  # newseq will be recorded from the curl output
  newseq=$(echo $_data | awk -F"," '{print $1}';);

  # newtime will be recorded from the curl output
  newtime=$(echo $_data | awk -F"," '{print $2}';);

  if [ ${startseq} -eq 0 ]; then
    # Record first seq and first timestamp
    startseq=$newseq
    starttime=$newtime
  else
    if [ ${prevseq} -ne ${newseq} ]; then
      # calculate for unique seq
  
      # calculating time difference between end time and prev time
      age=`(echo "$(( $(date -d "$newtime" '+%s') - $(date -d "$prevtime" '+%s') ))")`

      if [ ${mintime} -eq 0 ]; then
       # First time diff is copied to mintime/maxtime
        mintime=$age
        maxtime=$age
      fi

      # calculating mintime/maxtime for every iteration
      if [ $age -gt $maxtime ]; then
        maxtime=$age;
      else
        if [ $age -lt $mintime ]; then
          mintime=$age;
        fi
      fi
    fi
  fi

  prevseq=$newseq
  prevtime=$newtime

  # append age in plot file
  sed -i "$ s/$/,$age/" $PLOT_FILE

  #To be copied in output file
  echo time=$age &>> $LOG_FILE
  echo min=$mintime &>> $LOG_FILE
  echo max=$maxtime &>> $LOG_FILE
  echo S$startseq &>> $LOG_FILE
  echo P$prevseq &>> $LOG_FILE
  echo N$newseq &>> $LOG_FILE
  echo Count:$executioncount &>> $LOG_FILE
  echo New Time:$newtime &>> $LOG_FILE
  echo Prev Time:$prevtime &>> $LOG_FILE
}

###########################################################
# call server info and fetches ledger sequence / timestamp
# and then write the same in plot.csv 
# age is derived in script and then written in plot.csv file
# Arguments:
#   Poll interval 
# Returns:
#   True for Success
#   False for Failure
#########################################################

function fetch_server_info () {
  local _count=0;
  local _ret=$TRUE;
  local _interval=$1;
  local _failcount=0;
  local _http_response=0;
  local _http_body=0;
  local _http_status=0;
  local _closed=0;
  local _output=0;
  local _hostid=0;

  # No of times server info will be called to get validated
  # ledgers and timestamp
  while [ "${_count}" -lt  $CFG_POLLING_CNT ]
  do
    # HTTP get request
    _http_response=$(curl -v -s -L --write-out "HTTPSTATUS:%{http_code}" \
                  --max-redirs $CFG_MAX_REDIRECT --max-time 1\
                  -H "content-type: application/json" \
                  -X GET -d "{\"method\":\"$CFG_COMMAND\"}" $CFG_URL 2>> $LOG_FILE)

    # Retreive http body and response code
    _http_body=$(echo $_http_response | sed -e 's/HTTPSTATUS\:.*//g')
    _http_status=$(echo $_http_response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    if [ ! ${_http_status} -eq ${HTTP_OK} ]; then
      # HTTP GET Failure
      echo "Got $_http_status :( Not Connected Yet..." &>> $LOG_FILE
      case "${_http_status}" in
        "${HTTP_MOVED_PERMANENTLY}")
          echo "URL has changed permanently" &>> $LOG_FILE
        ;;
        "${HTTP_BAD_REQUEST}")
          echo "Server could not understand request" &>> $LOG_FILE
        ;;
        "${HTTP_FORBIDDEN}")
          echo "Client does not have access rights" &>> $LOG_FILE
        ;;
        "${HTTP_SERVICE_UNAVAILABLE}")
          echo "Server not ready to handle request" &>> $LOG_FILE
        ;;
        *)
          echo "Got ${_http_status} :( Not Connected Yet..." &>> $LOG_FILE
        ;;
      esac
      ((_failcount++))
    else
      _test=$(echo $_http_body | jq -r '.result.status');

      # remove double quotes from the return server status string
      _status=$(echo $_test | awk '{gsub(/'"'"'/,"",$1); print $1}');

      # check for server_info command status success/error
      if [ "${_status}" == "$STATUS_OK" ]; then
        # HTTP 200 OK
        echo "Got ${HTTP_OK} All done :) :)" &>> $LOG_FILE

        # Checking if the ledger is not a closed ledger
        if [[ `echo ${_http_body} | jq "(.result.info.validated_ledger.seq)"` !=  "null"  ]]; then

          # write timestamp and validated ledger seq in plot file
          # Not a closed ledger
          _output=$(echo ${_http_body} | jq -r "[.result.info.validated_ledger.seq, .result.info.time] | @csv" | awk -F"[ \"]" '{print $1 $3}');
          echo $_output >> $PLOT_FILE

          # Calculate time to get a validated ledger
          calculate_age $_output

          _hostid=$(echo ${_http_body} | jq -r "[.result.info.hostid] | @csv");

          # append hostid in plot file
          sed -i "$ s/$/,$_hostid/" $PLOT_FILE
        else
          # Not a Validated ledger (could be closed Ledger)
          _closed=$(echo ${_http_body} | jq "(.result.info.closed_ledger.seq)");
          echo "Validated Ledger Sequence recived as NULL closed:" $_closed &>> $LOG_FILE
          ((_closed_count++))
        fi
      else
        # server_info command status is not success
        echo "server_info Status ${_status} Failed" &>> $LOG_FILE
        ((_failcount++))
      fi
    fi
  
  # poll server info after polling interval seconds
  sleep ${_interval}

  # increment loop counter
  ((_count++))

  if [ ${_failcount} -eq $CFG_CHK_SERVER_CNT ]; then
    echo FAILCOUNT = $_failcount &>> $LOG_FILE 
    _ret=$FALSE;
    _count=$CFG_POLLING_CNT;
  fi

  done

return $_ret
}


# Main script start

# initialization steps
# create config directory if doesn't exist
[ ! -d "$CNF_DIR" ] && mkdir $CNF_DIR

# create output directory if doesn't exist
[ ! -d "$OUTPUT_DIR" ] && mkdir $OUTPUT_DIR

# create log directory if doesn't exist
[ ! -d "$LOG_DIR" ] && mkdir $LOG_DIR

# create config file with default values if doesn't exist
if [ ! -f "$CNF_FILE" ]; then

# Config File is Missing !!!
# Write out config file with default values for next time
cat <<HERE >$CNF_FILE
CONFIG_SERVER_URL=$URL
CFG_COMMAND=$COMMAND
CONFIG_MAX_REDIRECT=$MAX_REDIRECT
CONFIG_SERVER_DOWN_TIME_PERIOD=$DOWN_TIME_PERIOD
CONFIG_SERVER_POLLING_COUNT=$POLLING_COUNT
CONFIG_SERVER_SAMPLE_COUNT=$SAMPLE_COUNT
CONFIG_SERVER_POLLING_INTERVAL=1
HERE

fi

# Archiving old plot file by adding date timestamp
# plot file is in .csv format and it contains 
#   1) Validated ledger seq (retreived from the server info command)
#   2) timestamp (retreived from the server info command)
#   3) age (For how long each Ledger took to validate: calculated by script)
if [ -f "${PLOT_FILE}" ]; then
  pushd $OUTPUT_DIR >/dev/null 2>&1
  mv ${PLOT_FILE} plot_$(date +%F-%H:%M).csv
  popd >/dev/null
fi

# Archiving log file by adding date timestamp
if [ -f "${LOG_FILE}" ]; then
  pushd $LOG_DIR >/dev/null 2>&1
  mv ${LOG_FILE} log_$(date +%F-%H:%M).log
  popd >/dev/null
fi

# Archiving output file by adding date timestamp
if [ -f "${OUTPUT_FILE}" ]; then
  pushd $OUTPUT_DIR >/dev/null 2>&1
  mv ${OUTPUT_FILE} output_$(date +%F-%H:%M).log
  popd >/dev/null
fi

echo SCRIPT NAME= $SCRIPT_NAME &>> $LOG_FILE
echo SCRIPT VERSION = $SCRIPT_VERSION &>> $LOG_FILE
echo SCRIPT DATE = $SCRIPT_DATE &>> $LOG_FILE 
echo AUTHOR = $AUTHOR &>> $LOG_FILE
echo EMAIL = $EMAIL_ADDRESS &>> $LOG_FILE
echo PROGNAME = $PROGNAME &>> $LOG_FILE

if [ "$#" -eq 5 ]; then
  # Test code : Automated test executed by postexecution.bats file
  echo "Test Execution: " &>> $LOG_FILE
  CFG_URL=$1
  CFG_COMMAND=$2
  CFG_MAX_REDIRECT=$3
  CFG_POLLING_CNT=$4
  poll_interval=$5

else
  # Read Config File to update environment variables
  read_cfg_file

  # calculate polling interval
  if [ -e "${SCRIPT_DIR}/calculate_polling.sh" ]; then 
    # execute polling interval which call serverinfo command repeatedly 
    # and apply logic to decide polling interval
    # script copy the polling interval in cfg file
    # Arguments: 
    # 1) server url 2) server command 3) redirect count 4) sample count
    ${SCRIPT_DIR}/calculate_polling.sh ${CFG_URL} ${CFG_COMMAND} ${CFG_MAX_REDIRECT} ${CFG_SAMPLE_CNT}

    if [ "$?" -ne "$TRUE" ]; then
      error_exit "Error: running calculate_polling.sh script"
    fi
  else
    error_exit "Error: calculate_polling.sh script missing"
  fi

  # read config file again to retreive polling interval
  source $CNF_FILE
  poll_interval=$CONFIG_SERVER_POLLING_INTERVAL
fi

# call server repeatedly to retreive validated ledger seq and timestamp
fetch_server_info ${poll_interval}

if [ "$?" -ne "$TRUE" ]; then
  echo "fetch api: return code $FALSE" &>> $LOG_FILE
  error_exit "Error: fetch api return code Failed"
fi

# calculate average timestamp for timespan and update in output.txt file
cal_avg_timestamp

# Execute gnuplot
plot_graph

if [ "$?" -ne "$TRUE" ]; then
  echo "plot graph: return code $FALSE" &>> $LOG_FILE
  error_exit "Error: plot graph api return code Failed "
fi

graceful_exit
#End of script
