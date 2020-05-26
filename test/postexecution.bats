#!/usr/bin/env bats

load test_helper
load libs/bats-support/load
load libs/bats-assert/load
fixtures bats

BASE_DIR="$BATS_TEST_DIRNAME/.."
TEST_SCRIPT="$BASE_DIR/scripts/validated_ledger.sh"
POLLING_SCRIPT="$BASE_DIR/scripts/calculate_polling.sh"
CONFIG_FILE="$BASE_DIR/etc/validated_ledger.conf"


@test "check if config dir exist" {
  run ls $BASE_DIR/etc
  [ $status -eq 0 ]
}

@test "check if polling script failed with missing argument" {
  URL=https://s1.ripple.com:51234/
  CMD=server_inf
  MAX=1
  CNT=1

  run $BASE_DIR/scripts/calculate_polling.sh $URL $CMD $MAX
  [ $status -eq 1 ]
}

@test "check if polling script failed with wrong url" {
  URL=https://s1.ripple.com:5123/
  CMD=server_info
  MAX=1
  CNT=1

  run $BASE_DIR/scripts/calculate_polling.sh $URL $CMD $MAX $CNT
  [ $status -eq 1 ]
}

@test "check if polling script failed with wrong command" {
  URL=https://s1.ripple.com:51234/
  CMD=server_inf
  MAX=1
  CNT=1

  run $BASE_DIR/scripts/calculate_polling.sh $URL $CMD $MAX $CNT
  [ $status -eq 1 ]
}

@test "check if polling script execute succesfully" {
  URL=https://s1.ripple.com:51234/
  CMD=server_info
  MAX=1
  CNT=1

  run $BASE_DIR/scripts/calculate_polling.sh $URL $CMD $MAX $CNT
  [ $status -eq 0 ]
}

@test "check if config file is not removed after polling script execution" {
  run source $CONFIG_FILE
  [ $status -eq 0 ]
}

@test "check if validated ledger script execute succesfully" {
  URL=https://s1.ripple.com:51234/
  CMD=server_info
  MAX=1
  CNT=4
  interval=3

  run $BASE_DIR/scripts/validated_ledger.sh $URL $CMD $MAX $CNT $interval
  [ $status -eq 0 ]
}

@test "check if output dir exist" {
  run ls $BASE_DIR/output
  [ $status -eq 0 ]
}

@test "check if log dir exist" {
  run ls $BASE_DIR/log
  [ $status -eq 0 ]
}

@test "check if poll data file exist" {
  run ls "$BASE_DIR/output/polldata.csv"
  [ $status -eq 0 ]
}

@test "check if plot file exist" {
  run ls "$BASE_DIR/output/plot.csv"
  [ $status -eq 0 ]
}

@test "check if output file exist" {
  run ls "$BASE_DIR/output/output.txt"
  [ $status -eq 0 ]
}
