#!/bin/bash
# Script to easily install SSL keys for AMD rtm decryption process
# Chris Vidler - Dynatrace DCRUM SME 2016
#

# Config
RTMCONFIG=/usr/adlex/config/rtm.config
DEBUG=0

# Script below - do not edit
set -e
IFS='='

OPTS=0
while getopts ":dhc:k:" OPT; do
	case $OPT in
		c)
			RTMCONFIG=$OPTARG
			;;
		k)
			KEYFILE=$OPTARG
			OPTS=1
			;;
		d)
			DEBUG=1
			;;
		h)
			;;
		\?)
			echo -e "*** FATAL: Invalid option -$OPTARG"
			exit 1
			;;
		:)
			echo -e "*** FATAL: Option -$OPTARG requires an argument"
			exit 1
			;;
	esac
done

if [ $OPTS -eq 0 ]; then
	echo -e "*** INFO: Usage $0 [-h] [-c rtmconfig ] -k keyfile"
	exit 0
fi


# check if config file exists and is readable
if [ ! -r $RTMCONFIG ]; then
	echo -e "*** FATAL: Config file $RTMCONFIG not exists or not readable"
	exit
fi


# read config file, extract the key location info
KEYDIR=`cat $RTMCONFIG | grep server.key.dir`
KEYDIR=${KEYDIR##*=}
#echo $KEYDIR

KEYLIST=`cat $RTMCONFIG | grep server.key.list`
KEYLIST=${KEYLIST##*=}
KEYLISTNAME=$KEYLIST
KEYLIST=$KEYDIR$KEYLIST
#echo $KEYLIST


# check if locations exist and are writeable
if [ ! -d $KEYDIR ]; then
	echo -e "*** WARNING $KEYDIR doesn't exist, creating."
	mkdir -p $KEYDIR
fi

if [ ! -w $KEYDIR ]; then
	echo -e "*** FATAL Can't write to $KEYDIR"
	exit
fi

if [ ! -f $KEYLIST ]; then
	echo -e "*** WARNING Can't find $KEYLIST, creating."
	touch $KEYLIST
fi

if [ ! -w $KEYLIST ]; then
	echo -e "*** FATAL Can't write to $KEYLIST"
	exit
fi

# check if passed key file is readable
if [ ! -r $KEYFILE ]; then
	echo -e "*** FATAL Can't read key file: $KEYFILE"
	exit
fi


# parse key file, rudimentary check to see if it's valid
# use openssl check feature.
# if the key file is encrypted, user will be prompted for the password to decrypt it to check it.
echo -e "Checking validity of key file: $KEYFILE"
echo -e "You may be prompted for the key password if it's encrypted."
set +e
openssl rsa -check -noout -in $KEYFILE
RESULT=$?
set -e
#echo $RESULT
if [ $RESULT -ne 0 ]; then
	echo -e "*** FATAL Private key $KEYFILE not valid"
	exit
fi


# check keydir see if a conflicting name exists
BASENAME=`basename $KEYFILE`
#echo $BASENAME
if [ -f $KEYDIR$BASENAME ]; then
	echo -e "*** FATAL key with existing name: $BASENAME found."
	echo -e "Rename $KEYFILE and try again."
	exit
fi


# if we get here, everything checks out.
# rebuild keylist file to contain all of the keys in the keydir directory.


# copy new key into keydir
cp $KEYFILE $KEYDIR
if [ $? -ne 0 ]; then
	echo "*** FATAL: couldn't copy new key $KEYFILE into $KEYDIR"
	exit
fi


# set permissions
chmod 600 $KEYDIR$BASENAME
if [ $? -ne 0 ]; then
	echo -e "*** WARNING: Couldn't set secure permissions on new key $KEYDIR$BASENAME."
fi


# update keylist
echo -n "" > $KEYLIST
ls -1 $KEYDIR | grep -v $KEYLISTNAME | while read a; do
	echo -e "file,$a" >> $KEYLIST
done

echo -e "Key $KEYFILE installed and $KEYLIST updated."


