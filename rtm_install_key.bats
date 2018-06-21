#!/bin/env bats
#
# BATS test script for rtm_install_key
# Chris Vidler




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
  [ "${lines[0]}" == "*** INFO: Usage: ./key_convert.sh [-h] [-s] -k keyfile" ]
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

@test "key_convert.sh: test/convert non-existing key" {
  run ./key_convert.sh -k "invalidkeyname.key"
  echo -e "$output"
  [ $status -eq 1 ]
  expected="not readable."
  [[ "$output" =~ "$expected" ]]
} 

@test "key_convert.sh: test/convert PEM format key" {
  # build a new valid key to test
  TMPDIR=`mktemp -d`
  openssl genrsa -out "$TMPDIR/testkey.key"

  run ./key_convert.sh -k "$TMPDIR/testkey.key"
  echo -e "$output"
  [ $status -eq 0 ]
  expected="Complete. Saved: "
  [[ "$output" =~ "$expected" ]]

  rm -rf "$TMPDIR"
} 

@test "key_convert.sh: test invalid/corrupt PEM format key" {
  # build a new valid key to test
  TMPDIR=`mktemp -d`
  echo "not a valid file" > "$TMPDIR/testkey.key"

  run ./key_convert.sh -k "$TMPDIR/testkey.key"
  echo -e "$output"
  [ $status -eq 1 ]
  expected="invalid (not RSA), wrong format (not PEM) or wrong password."
  [[ "$output" =~ "$expected" ]]

  rm -rf "$TMPDIR"
} 

@test "key_convert.sh: test/convert DER format key" {
  # build a new valid key to test
  TMPDIR=`mktemp -d`
  openssl genrsa | openssl rsa -outform DER -out "$TMPDIR/testkey.der"

  run ./key_convert.sh -k "$TMPDIR/testkey.der"
  echo -e "$output"
  [ $status -eq 0 ]
  expected="Complete. Saved: "
  [[ "$output" =~ "$expected" ]]
  [ -r /tmp/tmp.key ]

  rm -f /tmp/tmp.key
  rm -rf "$TMPDIR"
} 

@test "key_convert.sh: test invalid/corrupt DER format key" {
  # build a new valid key to test
  TMPDIR=`mktemp -d`
  echo "not a valid file" > "$TMPDIR/testkey.der"

  run ./key_convert.sh -k "$TMPDIR/testkey.der"
  echo -e "$output"
  [ $status -eq 1 ]
  expected="*** FATAL: Couldn't convert DER to PEM"
  [[ "$output" =~ "$expected" ]]

  rm -rf "$TMPDIR"
} 

@test "key_convert.sh: test/convert PKCS12 format key" {
  # build a new valid key to test
  TMPDIR=`mktemp -d`
  openssl req -x509 -newkey rsa:2048 -keyout "$TMPDIR/testkey.key" -out "$TMPDIR/testkey.crt" -days 5 -nodes < <(echo -e "\n\n\n\n\n\n\n\n\n")
  openssl pkcs12 -export -out "$TMPDIR/testkey.p12" -inkey "$TMPDIR/testkey.key" -in "$TMPDIR/testkey.crt" -password stdin < <(echo -e "\n\n")
  [ -r "$TMPDIR/testkey.p12" ]

  run ./key_convert.sh -s -k "$TMPDIR/testkey.p12" < <(echo -e "\n")
  echo -e "$output"
  [ $status -eq 0 ]
  expected="Complete. Saved: "
  [[ "$output" =~ "$expected" ]]
  [ -r /tmp/tmp.key ]

  rm -f /tmp/tmp.key
  rm -rf "$TMPDIR"
} 

@test "key_convert.sh: test invalid/corrupt PKCS12 format key" {
  # build a new valid key to test
  TMPDIR=`mktemp -d`
  echo "not a valid file" > "$TMPDIR/testkey.p12"

  run ./key_convert.sh -k "$TMPDIR/testkey.p12"
  echo -e "$output"
  [ $status -eq 1 ]
  expected="*** FATAL: Couldn't extract private key from PKCS12 file"
  [[ "$output" =~ "$expected" ]]

  rm -rf "$TMPDIR"
} 

@test "key_convert.sh: test/convert JKS format key" {
 skip "not yet implemented"
}

@test "key_convert.sh: test invalid/corrupt JKS format key" {
 skip "not yet implemented"
}

@test "key_convert.sh: test invalid file type" {
  TMPDIR=`mktemp -d`
  echo "not a key" > "$TMPDIR/notakey.txt"
  run ./key_convert.sh -k "$TMPDIR/notakey.txt"
  echo $output
  [ $status -eq 1 ]
  expected="*** FATAL: Unable to determine key format of"
  [[ "$output" =~ "$expected" ]]
  rm -rf "$TMPDIR"
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



