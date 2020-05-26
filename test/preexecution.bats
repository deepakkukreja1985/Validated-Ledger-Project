#!/usr/bin/env bats

load test_helper
load libs/bats-support/load
load libs/bats-assert/load
fixtures bats

BASE_DIR="$BATS_TEST_DIRNAME/.."
TEST_SCRIPT="$BASE_DIR/scripts/validated_ledger.sh"
POLLING_SCRIPT="$BASE_DIR/scripts/calculate_polling.sh"
CONFIG_FILE="$BASE_DIR/etc/validated_ledger.conf"

@test "check if validated_ledger.sh script have executable permission" {
  [ -x "$TEST_SCRIPT" ]
  assert_success
}

@test "check if calculate_polling.sh script have executable permission" {
  [ -x "$POLLING_SCRIPT" ]
  assert_success
}

@test "check if config dir exist" {
  run ls $BASE_DIR/etc
  [ $status -eq 0 ]
}

@test "check if validated_ledger.conf file exist" {
  run ls $CONFIG_FILE
  [ $status -eq 0 ]
}

@test "check if plot.dat file exist" {
  run ls "$BASE_DIR/etc/plot.dat"
  [ $status -eq 0 ]
}

@test "check if curl exist" {
  run curl --version
  [ $status -eq 0 ]
}

@test "check if jq exist" {
  run jq --version
  [ $status -eq 0 ]
}

@test "check if gnuplot exist" {
  run gnuplot --version
  [ $status -eq 0 ]
}
