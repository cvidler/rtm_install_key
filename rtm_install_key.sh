#!/bin/bash
# Script to easily install SSL keys for AMD rtm decryption process
# Chris Vidler - Dynatrace DCRUM SME 2016
#

# Config
RTMCONFIG=/usr/adlex/config/rtm.config
DEBUG=0
RESTART=1
LISTKEYS=0
RTMTYPE=rtm

# Script below - do not edit
set -e
IFS='='

OPTS=0
while getopts ":dhc:k:rRszl" OPT; do
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
		r)
			RESTART=1
			;;
		R)
			RESTART=0
			;;
		s)
			SCRIPTED=1
			;;
		z)
			UNDEPLOY=1
			;;
		l)
			LISTKEYS=1
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
	echo -e "*** INFO: Usage $0 [-h] [-c rtmconfig ] [-r|-R] [-l] [-u] -k keyfile"
	echo -e "-h			This help"
	echo -e "-r			Restart rtm daemon. Default."
	echo -e "-R			DO NOT restart rtm daemon."
	echo -e "-c			location of rtm.config file. Default: $RTMCONFIG"
	echo -e "-l			List active keys post any changes."
	echo -e "-z			Undeploy and delete key."
	echo -e "-k keyfile	Private key to deploy. Required."
	exit 0
fi


# check if config file exists and is readable
if [ ! -r $RTMCONFIG ]; then
	echo -e "*** FATAL: Config file $RTMCONFIG not exists or not readable"
	exit 1
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

RTMTEST=`cat $RTMCONFIG | grep rtm.type`
RTMTEST=${RTMTYPE##*=}
#determine name of daemon
if [ RTMTEST == rtmhs ]; then
	RTMTYPE=rtmhs
else
	RTMTYPE=rtm
fi
echo -e "***DEBUG: RTMTYPE=$RTMTYPE"


# check if locations exist and are writeable
if [ ! -d $KEYDIR ]; then
	echo -e "*** WARNING $KEYDIR doesn't exist, creating."
	mkdir -p $KEYDIR
fi

if [ ! -w $KEYDIR ]; then
	echo -e "*** FATAL Can't write to $KEYDIR"
	exit 1
fi

if [ ! -f $KEYLIST ]; then
	echo -e "*** WARNING Can't find $KEYLIST, creating."
	touch $KEYLIST
fi

if [ ! -w $KEYLIST ]; then
	echo -e "*** FATAL Can't write to $KEYLIST"
	exit 1
fi

# check if passed key file is readable
if [ ! -r $KEYFILE ]; then
	if [ ! $UNDEPLOY -eq 1 ]; then		#ignore if undeploy is set, don't need the file to exist in this case.
		echo -e "*** FATAL Can't read key file: $KEYFILE"
		exit 1
	fi
fi


# parse key file, rudimentary check to see if it's valid
# use openssl check feature.
# if the key file is encrypted, user will be prompted for the password to decrypt it to check it.
if [ ! $SCRIPTED -eq 1 ]; then
	if [ ! $UNDEPLOY ]; then		#ignore if undeploy is set, don't need the file to exist in this case.
		echo -e "Checking validity of key file: $KEYFILE"
		echo -e "You may be prompted for the key password if it's encrypted."
		set +e
		openssl rsa -check -noout -in $KEYFILE
		RESULT=$?
		set -e
		#echo $RESULT
		if [ $RESULT -ne 0 ]; then
			echo -e "*** FATAL Private key $KEYFILE not valid"
			exit 1
		fi
	fi
fi


# check keydir see if a conflicting name exists
BASENAME=`basename $KEYFILE`
#echo $BASENAME
if [ -f $KEYDIR$BASENAME ]; then
	if [ ! $UNDEPLOY ]; then		#ignore if undeploy is set, expect the file to exist in this case.
		echo -e "*** FATAL key with existing name: $BASENAME found."
		echo -e "Rename $KEYFILE and try again."
		exit 1
	fi
fi


# if we get here, everything checks out.
# rebuild keylist file to contain all of the keys in the keydir directory.


if [ ! $UNDEPLOY ]; then
	# copy new key into keydir
	cp $KEYFILE $KEYDIR
	if [ $? -ne 0 ]; then
		echo "*** FATAL: couldn't copy new key $KEYFILE into $KEYDIR"
		exit 1
	fi

	# set permissions
	chmod 600 $KEYDIR$BASENAME
	if [ $? -ne 0 ]; then
		echo -e "*** WARNING: Couldn't set secure permissions on new key $KEYDIR$BASENAME."
	fi
else
	shred -uf $KEYDIR$BASENAME
	if [ $? -ne 0 ]; then
		echo -e "*** FATAL: couldn't remove key $BASENAME"
		exit 1
	fi
fi

#update keylist, populate with all key files in the keydir directory
echo -n "" > $KEYLIST
ls -1 $KEYDIR | grep -v $KEYLISTNAME | while read a; do
	echo -e "file,$a" >> $KEYLIST
done

if [ ! $UNDEPLOY ]; then

	echo -e "Key $KEYFILE installed and $KEYLIST updated."

	if [ $SCRIPTED -eq 1 ]; then
		#clean up temporary copy of private key
		shred -uf $KEYFILE
		if [ $? -ne 0 ]; then
			echo -e "*** WARNING: Couldn't remove temporary copy of private key: ${DEPPATH}${DEPFILE##*/}"
		fi
	fi
else
	echo -e "Key $KEYFILE removed and $KEYLIST updated."	
	echo -e "Change takes effect at next $RTMTYPE daemon restart."
fi


if [ $RESTART -eq 1 ]; then
	echo -e "Restarting rtm daemon $RTMTYPE."
	service $RTMTYPE restart
	if [ $? -ne 0 ]; then
		echo -e "*** WARNING: Couldn't restart daemon $RTMTYPE."
		exit 1
	fi
fi

if [ $LISTKEYS -eq 1 ]; then
	echo -e "Current list of configured keys:"
	echo -e `cat $KEYLIST`
fi

exit 0

