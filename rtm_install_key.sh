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


# command line to live reload keys on v17+ 
LIVERELOAD_CMD="sudo rcmd ssldecr keys reload"
GETVERSION_CMD="sudo rcmd show version | grep -E 'rtmhs\.17\.' | wc -l"

# Script below - do not edit
set -e
IFS='='


function debugecho {
	LVL=${2:-1}
	if test $DEBUG -ge $LVL ; then echo -e "\e[2m***DEBUG[${LVL}]:\e[0m $1"; fi
}

function fatalecho {
	if [[ $DEBUG -ne 0 ]]; then echo -e "\e[31m***FATAL: $@\e[0m"; exit 1; fi
}

function warningecho {
	if [[ $DEBUG -ne 0 ]]; then echo -e "\e[33m***WARNING: $@\e[0m"; fi
}




OPTS=0
UNDEPLOY=0
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
			DEBUG=$((DEBUG + 1))
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



# for later
ME=$0
if [ $SCRIPTED -eq 1 ]; then rm $ME; fi


# check if config file exists and is readable
if sudo test ! -r $RTMCONFIG ; then
	fatalecho "Config file $RTMCONFIG not exists or not readable"
fi

# read config file, extract the key location info
KEYDIR=`sudo cat $RTMCONFIG | grep server.key.dir`
KEYDIR=${KEYDIR##*=}
debugecho "KEYDIR: '$KEYDIR'"

KEYLIST=`sudo cat $RTMCONFIG | grep server.key.list`
KEYLIST=${KEYLIST##*=}
KEYLISTNAME=$KEYLIST
KEYLIST=$KEYDIR$KEYLIST
debugecho "KEYLIST: '$KEYLIST'"

RTMTEST=`sudo cat $RTMCONFIG | grep rtm.type`
debugecho "RTMTEST: $RTMTEST", 2
RTMTEST=${RTMTEST##*=}
debugecho "RTMTEST: $RTMTEST", 2
#determine name of daemon
if [ "$RTMTEST" == "rtmhs" ]; then
	RTMTYPE="rtmhs"
else
	RTMTYPE="rtm"
fi
debugecho "RTMTYPE: '$RTMTYPE'"
debugecho "UNDEPLOY: '$UNDEPLOY'"


# check if locations exist and are writeable
if sudo test ! -d $KEYDIR ; then
	warningecho "$KEYDIR doesn't exist, creating."
	sudo mkdir -p $KEYDIR
fi

if sudo test ! -w $KEYDIR ; then
	fatalecho "Can't write to $KEYDIR"
fi

if sudo test ! -f $KEYLIST ; then
	debugecho "Can't find $KEYLIST, creating."
	sudo touch $KEYLIST
fi

if sudo test ! -w $KEYLIST ; then
	fatalecho "Can't write to $KEYLIST"
fi

# check if passed key file is readable
if [ ! -r $KEYFILE ]; then
	if [ ! $UNDEPLOY -eq 1 ]; then		#ignore if undeploy is set, don't need the file to exist in this case.
		fatalecho -e "Can't read key file: $KEYFILE"
		exit 1
	fi
fi


# parse key file, rudimentary check to see if it's valid
# use openssl check feature.
# if the key file is encrypted, user will be prompted for the password to decrypt it to check it.
if [ ! $SCRIPTED -eq 1 ]; then
	if [ ! $UNDEPLOY -eq 1 ]; then		#ignore if undeploy is set, don't need the file to exist in this case.
		echo -e "Checking validity of key file: $KEYFILE"
		echo -e "You may be prompted for the key password if it's encrypted."
		set +e
		openssl rsa -check -noout -in $KEYFILE
		RESULT=$?
		set -e
		#echo $RESULT
		if [ $RESULT -ne 0 ]; then
			fatalecho "Private key $KEYFILE not valid"
			exit 1
		fi
	fi
fi


# check keydir see if a conflicting name exists
BASENAME=`basename $KEYFILE`
#echo $BASENAME
if [ -f $KEYDIR$BASENAME ]; then
	if [ ! $UNDEPLOY -eq 1 ]; then		#ignore if undeploy is set, expect the file to exist in this case.
		echo -e "*** FATAL key with existing name: $BASENAME found."
		echo -e "Rename $KEYFILE and try again."
		exit 1
	fi
fi


# if we get here, everything checks out.
# rebuild keylist file to contain all of the keys in the keydir directory.


if [ ! $UNDEPLOY -eq 1 ]; then
	# copy new key into keydir
	debugecho "copying $KEYFILE to $KEYDIR."
	sudo cp $KEYFILE $KEYDIR
	if [ $? -ne 0 ]; then
		fatalecho "Couldn't copy new key $KEYFILE into $KEYDIR"
		exit 1
	fi

	# set permissions
	sudo chmod 600 $KEYDIR$BASENAME
	if [ $? -ne 0 ]; then
		warningecho "Couldn't set secure permissions on new key $KEYDIR$BASENAME."
	fi
elif [ $UNDEPLOY -eq 1 ] && sudo test -r $KEYDIR$BASENAME ; then
	debugecho "Removing key: '$KEYDIR$BASENAME'"
	sudo shred -uf $KEYDIR$BASENAME
	if [ $? -ne 0 ]; then
		fatalecho "Couldn't remove key $KEYDIR$BASENAME"
	fi
fi

# update keylist, populate with all key files in the keydir directory
sudo rm $KEYLIST
if [ $? -ne 0 ]; then fatalecho "Can't rm $KEYLIST."; fi
sudo ls -1 $KEYDIR | grep -v $KEYLISTNAME | while read a; do
	echo "file,$a" | sudo tee -a $KEYLIST
	if [ $? -ne 0 ]; then fatalecho "Can't properly update $KEYLIST."; fi
done

if [ $UNDEPLOY -eq 0 ]; then

	echo -e "Key $KEYFILE installed and $KEYLIST updated."

	if [ $SCRIPTED -eq 1 ]; then
		# clean up temporary copy of private key
		sudo shred -uf $KEYFILE
		if [ $? -ne 0 ]; then
			warningecho "Couldn't remove temporary copy of private key: ${DEPPATH}${DEPFILE##*/}"
		fi
	fi
else
	echo -e "Key $KEYFILE removed and $KEYLIST updated."	
fi

echo -e "Change takes effect at next $RTMTYPE daemon restart."

debugecho "RESTART: '$RESTART'"
if [ $RESTART -eq 1 ]; then

	#test version number for live reload
	IS17=`$GETVERSION_CMD`

	if [ ! $IS17 = 1 ]; then
		echo -e "Restarting rtm daemon $RTMTYPE."
		sudo service $RTMTYPE restart
		if [ $? -ne 0 ]; then
			warningecho "Couldn't restart daemon $RTMTYPE."
			exit 1
		fi
	else
		echo -e "Reloading Keys"
		$LIVERELOAD_CMD
	fi
fi

if [ $LISTKEYS -eq 1 ] && sudo test -r $KEYLIST ; then
	echo -e "Current list of configured keys:"
	echo -e `sudo cat $KEYLIST`
fi

exit 0


