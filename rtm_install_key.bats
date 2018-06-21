#!/bin/env bats
#
# BATS test script for rtm_install_key
# Chris Vidler


setup() {

  #create temp directory and populate with temp key material
  TMPDIR=`mktemp -d`

  openssl genrsa -out "$TMPDIR/testkey.key"

}

teardown() {
  # cleanup temp directory
  rm -rf "$TMPDIR"
}




##
## deploy_keys.sh
##

@test "deploy_keys.sh: script present" {
  [ -r deploy_keys.sh ]
}

@test "deploy_keys.sh: script executable" {
  [ -x deploy_keys.sh ]
}

@test "deploy_keys.sh: no parameter test" {
  run ./deploy_keys.sh
  [ $status -eq 0 ]
  [ "${lines[0]}" == "*** INFO: Usage: ./deploy_keys.sh [-h] [-R|r] [-z -z] -a amdaddress|listfile -f privatekey [-u user] [-p password | -i identfile]" ]
} 

@test "deploy_keys.sh: invalid parameter test" {
  run ./deploy_keys.sh -g
  [ $status -eq 0 ]
  expected="***WARNING: Invalid argument [-g]."
  [[ "$output" =~ "$expected" ]]
} 

@test "deploy_keys.sh: missing parameter value test" {
  run ./deploy_keys.sh -a
  [ $status -eq 0 ]
  expected="***WARNING: argument [-a] requires parameter."
  [[ "$output" =~ "$expected" ]]
} 



##
## key_convert.sh
##

@test "key_convert.sh: script present" {
  [ -r key_convert.sh ]
}

@test "key_convert.sh: script executable" {
  [ -x key_convert.sh ]
}

@test "key_convert.sh: no parameter test" {
  run ./key_convert.sh
  [ $status -eq 0 ]
  [ "${lines[0]}" == "*** INFO: Usage: ./key_convert.sh [-h] -k keyfile" ]
} 

@test "key_convert.sh: invalid parameter test" {
  run ./key_convert.sh -g
  [ $status -eq 1 ]
  expected="*** FATAL: Invalid argument -g."
  [[ "$output" =~ "$expected" ]]
} 

@test "key_convert.sh: missing parameter value test" {
  run ./key_convert.sh -k
  [ $status -eq 1 ]
  expected="*** FATAL: argument -k requires parameter."
  [[ "$output" =~ "$expected" ]]
} 

@test "key_convert.sh: test/convert PEM format key" {
  run ./key_convert.sh -k "$TMPDIR/testkey.key"
  [ $status -eq 0 ]
  expected="Complete. Saved: "
  [[ "$output" =~ "$expected" ]]
} 



##
## rtm_install_key.sh
##


@test "rtm_install_key.sh: script present" {
  [ -r rtm_install_key.sh ]
}

@test "rtm_install_key.sh: script executable" {
  [ -x rtm_install_key.sh ]
}

@test "rtm_install_key.sh: no parameter test" {
  run ./rtm_install_key.sh
  [ $status -eq 0 ]
  [ "${lines[0]}" == "*** INFO: Usage ./rtm_install_key.sh [-h] [-c rtmconfig ] [-r|-R] [-l] [-u] -k keyfile" ]
} 

@test "rtm_install_key.sh: invalid parameter test" {
  run ./rtm_install_key.sh -g
  [ $status -eq 1 ]
  expected="*** FATAL: Invalid option -g"
  [[ "$output" =~ "$expected" ]]
} 

@test "rtm_install_key.sh: missing parameter value test" {
  run ./rtm_install_key.sh -k
  [ $status -eq 1 ]
  expected="*** FATAL: Option -k requires an argument"
  [[ "$output" =~ "$expected" ]]
} 



