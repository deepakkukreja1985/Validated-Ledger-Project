#!/bin/bash

##############################################################################
# Script Name         : calculate_polling.sh
# Desicription        : This shell script calculates polling interval during 
#                       runtime by calculating the average time taken by the
#                       server to generate unique validated ledger sequences.
#                       The count  of unique validated sequence that needs to
#                       be captured for polling interval calculation is stored
#                       in conf file parameter  : CONFIG_SERVER_SAMPLE_COUNT
# Author              : Deepak Kukreja
# Date                : 2020/05/25
# Revision History    : 0.1
##############################################################################

# Argument assigned to variable to be use in script
CFG_URL=$1
CFG_COMMAND=$2
CFG_MAX_REDIRECT=$3
CFG_SAMPLE_CNT=$4

# Exit Codes
HTTP_OK=200
HTTP_MOVED_PERMANENTLY=301
HTTP_BAD_REQUEST=400
HTTP_FORBIDDEN=403
HTTP_SERVICE_UNAVAILABLE=504

# Status Codes
STATUS_OK="success"
STATUS_ERR="error"
declare -r TRUE=0
declare -r FALSE=1

# Path Variables
BASE_DIR=`pwd`
OUTPUT_DIR=$BASE_DIR/output
CNF_DIR=$BASE_DIR/etc
LOG_DIR=$BASE_DIR/log
LOG_FILE="${LOG_DIR}/log.txt"
POLLDATA_FILE=${OUTPUT_DIR}/polldata.csv
CNF_FILE="${CNF_DIR}/validated_ledger.conf"
POLLING_INTERVAL=0


# Perform pre-exit housekeeping
# error exit in case of error
error_exit() {
  echo -e "${PROGNAME}: ${1:- "Unknown Error"}" &>> $LOG_FILE
  exit $FALSE
}

# Perform pre-exit housekeeping
# gracefule exit at the end
graceful_exit() {
  exit $TRUE
}

#############################################################
# Calculate Polling interval
# loop is incremented for only unique sequence.
# loop work till counter reaches CFG_SAMPLE_CNT.
# Arguments:
#   None
# Returns:
#   TRUE or FALSE
#############################################################

function calc_polling_interval () {
  local _executioncount=0;  # loop counter
  local _failcount=0;       # fail counter
  local _prevseq=0;         # store previous seq no
  local _newseq=0;          # store new seq no
  local _starttime=0;       # store start time of polling
  local _endtime=0;         # store end time of polling
  local _http_body=0;       # stroe http body
  local _http_response=0;   # output of curlhttp request
  local _http_status=0;     # store http status
  local _output=0;
  local _ret=${TRUE};       # retrurn variable

  while [ "${_executioncount}" -lt $CFG_SAMPLE_CNT ]
  do
    # HTTP get request
    _http_response=$(curl -v -s -L --write-out "HTTPSTATUS:%{http_code}" \
                  --max-redirs $CFG_MAX_REDIRECT --max-time 1\
                  -H "content-type: application/json" \
                  -X GET -d "{\"method\":\"$CFG_COMMAND\"}" $CFG_URL 2>> $LOG_FILE)

    # Retreive http body and response code
    _http_body=$(echo $_http_response | sed -e 's/HTTPSTATUS\:.*//g')
    _http_status=$(echo $_http_response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    if [ $_http_status -ne $HTTP_OK ]; then
      # HTTP GET Failure
      echo "Got $_http_status :( Not Connected Yet..." &>> $LOG_FILE
      case "${_http_status}" in
        "${HTTP_MOVED_PERMANENTLY}")
          echo "URL has changed permanently" &> $LOG_FILE
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
      _test=$(echo $_http_body | jq -r '.result.status')
      _status=$(echo $_test | awk '{gsub(/'"'"'/,"",$1); print $1}');

      # check for server_info command status code
      # status code can be "success" or "error"
      if [ "${_status}" == "$STATUS_OK" ]; then

        # HTTP 200 OK
        # Checking if the ledger is not a closed ledger

        if [[ `echo $_http_body | jq "(.result.info.validated_ledger.seq)"` !=  "null"  ]];then

          # jq to convert seq and time in csv format
          # awk to fetch only time from the full timestamp received
          _output=$(echo $_http_body | \
                 jq -r "[.result.info.validated_ledger.seq, .result.info.time] | @csv" | \
                 awk -F"[ \"]" '{print $1 $3}');

          # output is copied in polldata.csv file
          echo $_output >> $POLLDATA_FILE

          # newseq will be recorded on from the curl output
          _newseq=$(echo $_output | awk -F"," '{print $1}';);

          if [ $_executioncount -eq 0 ]; then
            # starttime will be recorded from the curl output
            _starttime=$(echo $_output | awk -F"," '{print $2}';);
            _prevseq=$_newseq
            ((_executioncount++))
          else
            # check for unique sequence and then only increment counter
            if [ $_prevseq -ne $_newseq ]; then
              _prevseq=$_newseq
              ((_executioncount++))
            fi
          fi
        else
          # Validated Polling count is Null i.e Close Ledger is received
          echo "Polling: Validated Ledger Failed" &>> $LOG_FILE
        fi
      else
        # server_info command status is not success
        echo "server_info Status ${_status} Failed" &>> $LOG_FILE
        ((_failcount++))
      fi
    fi

  # retrun FALSE if failcount equal to CFG_SAMPLE_CNT
  if [ $_failcount -eq $CFG_SAMPLE_CNT ]; then
    _ret=$FALSE;
    _executioncount=$CFG_SAMPLE_CNT;
  fi

  done

  # storing end time of the last validated ledger as per sample
  _endtime=$(echo $_output | awk -F"," '{print $2}';);

  # calculating time difference between start and end time
  _timediff=`(echo "$(( $(date -d "${_endtime}" '+%s') - $(date -d "${_starttime}" '+%s') ))")`

  # taking average time interval
  POLLING_INTERVAL=$(($_timediff/$CFG_SAMPLE_CNT))

  echo POLLING:$POLLING_INTERVAL &>> $LOG_FILE

  return $_ret
}


# Main script start

# check for argument.
# Polling script will not work in case of missing arguments
if [ "$#" -ne 4 ]; then
  error_exit "Error: Argument Missing Count:$#"
fi

# Rename old output file by adding date
if [ -f "$POLLDATA_FILE" ]; then
  pushd $OUTPUT_DIR >/dev/null
  mv $POLLDATA_FILE poll_$(date +%F-%H:%M).csv
  popd >/dev/null
fi

# calculate polling interval
calc_polling_interval
if [ "$?" -eq ${TRUE} ]; then

  # overwrite the value of parameter in config file
  sed -i "s/^CONFIG_SERVER_POLLING_INTERVAL=.*$/CONFIG_SERVER_POLLING_INTERVAL=$POLLING_INTERVAL/g" $CNF_FILE
  if [ "$?" -ne ${TRUE} ]; then
    error_exit "Error: Polling api Failed"
  fi

else
  error_exit "Error: Polling api Failed"
fi

graceful_exit
#End of script
