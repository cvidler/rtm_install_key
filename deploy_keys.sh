#! /bin/bash
#
# deploy_keys.sh
# Chris Vidler - Dynatrace DCRUM SME - 2016
# Deploy SSL private keys to remote AMDs
#

#script defaults
DEPPATH=/tmp
DEPSCRIPT=rtm_install_key.sh
DEPUSER=root
DEPPASS=greenmouse
DEPEXEC=1
IDENT=""
RESTART=1



#script follows do not edit.

function debugecho {
	if [[ $DEBUG -ne 0 ]]; then echo -e "\e[2m***DEBUG: $@\e[0m"; fi
}

function setdebugecho {
	if [[ $DEBUG -ne 0 ]]; then echo -ne "\e[2m"; fi
}

function unsetdebugecho {
	if [[ $DEBUG -ne 0 ]]; then echo -ne "\e[0m"; fi
}



#command line parameters
OPTS=0
while getopts ":hdrRf:a:u:p:i:x:z" OPT; do
	case $OPT in
		h)
			OPTS=0	#show help
			;;
		d)
			DEBUG=1
			;;
		f)
			OPTS=1
			DEPFILE=$OPTARG
			;;
		r)
			OPTS=1
			RESTART=1
			;;
		R)
			OPTS=1
			RESTART=0
			;;
		a)
			OPTS=1
			AMDADDR=$OPTARG
			;;
		u)
			OPTS=1
			DEPUSER=$OPTARG
			;;
		p)
			OPTS=1
			DEPPASS=$OPTARG
			;;
		i)
			if [ -r $OPTARG ]; then
				OPTS=1
				IDENT=" -i $OPTARG"
				DEPPASS=""
			else
				OPTS=0
				echo -e "\e[31m*** FATAL:\e[0m Identity file $OPTARG not present or inaccessible."
				exit 1
			fi
			;;
		x)
			OPTS=1
			RUNCMD=$OPTARG
			;;
		z)
			OPTS=1
			UNDEPLOY=1
			RESTART=0
			;;
		\?)
			OPTS=0 #show help
			echo "*** FATAL: Invalid argument -$OPTARG."
			;;
		:)
			OPTS=0 #show help
			echo "*** FATAL: argument -$OPTARG requires parameter."
			;;
	esac
done

#abort, showing help, if required options are unset
if [ "$DEPFILE" == "" ]; then OPTS=0; fi
if [ "$AMDADDR" == "" ]; then OPTS=0; fi

#check if passed restart schedule is a valid format 'now' or a +m (number of minutes), or hh:mm (24hr clock)
#if [[ $RESTARTSCHED =~ ^now$ ]]; then
#	# 'now', OK
#	echo -n
#elif [[ $RESTARTSCHED =~ ^\+[0-9]+$ ]]; then
#	# +m minutes, OK
#	echo -n
#elif [[ $RESTARTSCHED =~ ^(2[0-3]|1[0-9]|0?[0-9]):[0-5][0-9]$ ]]; then
#	# hh:mm 24-hr clock, OK
#	echo -n
#else
#	#unknown schedule, show help
#	echo -e "\e[31m*** FATAL:\e[0m Restart schedule '$RESTARTSCHED' invalid."
#	OPTS=0
#fi

#check for required script file
if [ ! -r $DEPSCRIPT ]; then
	echo -e "\e[31m*** FATAL:\e[0m Required script '$DEPSCRIPT' not found or inaccessible."
	exit 1
fi


if [ $OPTS -eq 0 ]; then
	echo -e "*** INFO: Usage: $0 [-h] [-E|-e] [-R|r] [-s hh:mm|+m|now] [-z] -a amdaddress|listfile -f privatekey [-u user] [-p password | -i identfile]"
	echo -e "-h 	This help"
	echo -e "-a amdaddress|listfile "
	echo -e "		address or if a file list one per line for AMDs to deploy to. Required."
	echo -e "-f privatekey "
	echo -e "		Full path to privatekey file. Required."
	echo -e "-u user "
	echo -e "		User with root or sudo rights to copy and execute key update script. Default root."
	echo -e "-p password "
	echo -e "		Password for user. Default greenmouse."
	echo -e "-i identfile "
	echo -e "		SSH private key identity file."
	echo -e "-r 	Restart rtm process once copied. Default."
	echo -e "-R 	DO NOT Restart rtm process once copied."
	echo -e ""
	echo -e "-z		undeploy/remove (and secure erase) private key named in '-f privatekey' parameter"
	echo -e ""
	echo -e "-p and -i are exclusive, -i takes precedence as it is more secure."
	exit 0
fi

#check if passed file is readable.
if [ ! -r $DEPFILE ]; then
	if [ $UNDEPLOY == 0 ]; then
		echo -e "\e[31m*** FATAL:\e[0m Upgrade file $DEPFILE not present or inaccessible."
		exit 1
	fi
fi

#check if passed amd address is a file (treat it as a list) or not (a single amd address).
if [ -r $AMDADDR ]; then
	#it's a list file
	#read file loading each line into var
	AMDLIST=""
	while read line; do
		if [[ $line == "#"* ]]; then continue; fi		#skip comments
		if [[ $line == "" ]]; then continue; fi			# blank lines

		if [[ $line =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|[a-zA-Z0-9\.-]+|\[?[0-9a-fA-F:]+\]?)$ ]]; then		#rudimentary ip/fqdn/ipv6 test
			AMDLIST="$AMDLIST$line\n"
		else
			debugecho "AMDLIST nonmatching line: ${line}"
		fi
	done < <(cat $AMDADDR)
	AMDLIST=${AMDLIST%%\\n}		#remove trailing comma
else
	#it's not a list file. nothing to do.
	AMDLIST=$AMDADDR
fi


debugecho "Configuration:"
debugecho "DEPUSER: '$DEPUSER', DEPPASS: '$DEPPASS', IDENT: '$IDENT', AMDADDR: '$AMDADDR', DEPSCRIPT: '$DEPSCRIPT' "
debugecho "DEPPATH: '$DEPPATH', RESTART: '$RESTART', RESTARTSCHED: '$RESTARTSCHED', DEPEXEC: '$DEPEXEC' "
debugecho "UNDEPLOY: '$UNDEPLOY', "
debugecho "AMDLIST: '$AMDLIST' "

#exit

#get dependencies for config
SCP=`which scp`
if [ $? -ne 0 ]; then
	echo -e "\e[31m*** FATAL:\e[0m dependency 'scp' not found."
	exit 1
fi
SSH=`which ssh`
if [ $? -ne 0 ]; then
	echo -e "\e[31m*** FATAL:\e[0m dependency 'ssh' not found."
	exit 1
fi
debugecho "SCP: '$SCP', SSH: '$SSH' "


#build configs
if [ $DEBUG == 1 ]; then VERBOSE=" -v"; fi		#in debug mode add verbosity to SCP and SSH commands later on

#DEPPASS="$DEPPASS"
if [ ! "$IDENT" == "" ]; then 
	# if ident file to be used clear any default or user set password.
	DEPPASS=""
else
	# if user supplied password is required, need to use 'sshpass' to automatically pass it to both SCP and SSH.
	SSHPASSE=`which sshpass`
	if [ $? -ne 0 ]; then
		echo -e "\e[31m*** FATAL:\e[0m dependency 'sshpass' not found."
		exit 1
	fi
	debugecho "SSHPASSE: $SSHPASSE"
	SSHPASS=${DEPPASS}
	DEPPASS="${SSHPASSE} -e "
	#debugecho "SSHPASS: $SSHPASS"
	debugecho "DEPPASS: '$DEPPASS'"
fi
#AMDADDR="@$AMDADDR"
#DEPPATH=":$DEPPATH" 

if [ $RESTART = 1 ]; then RESTART="-r"; else RESTART="-R"; fi


if [ ! -x $DEPSCRIPT ]; then chmod +x $DEPSCRIPT; debugecho "chmod +x to '$DEPSCRIPT'"; fi

SUCCESS=""
FAIL=""

#exit

while read line; do

	AMDADDR=$line
	echo -e "\e[34mdeploy_keys.sh\e[0m Deploying ${DEPFILE##*/} to ${AMDADDR}"

	#build SCP command line
	if [ $UNDEPLOY ]; then
		SCPCOMMAND="${DEPPASS}${SCP}${VERBOSE} -p${IDENT} $DEPSCRIPT ${DEPUSER}@${AMDADDR}:${DEPPATH}"
	else
		SCPCOMMAND="${DEPPASS}${SCP}${VERBOSE} -p${IDENT} $DEPSCRIPT ${DEPFILE} ${DEPUSER}@${AMDADDR}:${DEPPATH}"
	fi
	debugecho "SCP command: $SCPCOMMAND"

	#export envvar for sshpass
	export SSHPASS=$SSHPASS

	#run SCP command
	setdebugecho
	RESULT=`$SCPCOMMAND`
	EC=$?
	unsetdebugecho
	if [[ $EC -ne 0 ]]; then
		echo -e "\e[31m*** FATAL:\e[0m SCP to ${AMDADDR} failed."
		FAIL="${FAIL}${AMDADDR}\n"
		continue
	fi
	echo -e "\e[32m*** SUCCESS:\e[0m Copied ${DEPFILE##*/} to ${AMDADDR}."
	if [ $DEPEXEC == 0 ]; then SUCCESS="${SUCCESS}${AMDADDR}\n"; fi

	#build SSH command line to run copied file
	if [ "$DEPEXEC" == "1" ]; then
		if [ $UNDEPLOY ]; then
			SSHCOMMAND="${DEPPASS}${SSH}${VERBOSE} ${IDENT} ${DEPUSER}@${AMDADDR} ${DEPPATH}/${DEPSCRIPT##*/} -s -u ${RESTART} -k ${DEPFILE##*/}"
		else
			SSHCOMMAND="${DEPPASS}${SSH}${VERBOSE} ${IDENT} ${DEPUSER}@${AMDADDR} ${DEPPATH}/${DEPSCRIPT##*/} -s ${RESTART} -k ${DEPPATH}/${DEPFILE##*/}"
		fi
		debugecho "SSH command: $SSHCOMMAND"

		#run SSH command
		setdebugecho
		RESULT=`$SSHCOMMAND`
		EC=$?
		unsetdebugecho
		debugecho $RESULT
		if [ $EC == 0 ]; then
			echo -n
		elif [ $EC == 255 ]; then
			echo -e "\e[31m*** FATAL:\e[0m SSH to ${AMDADDR} failed. EC=$EC"
			FAIL="${FAIL}${AMDADDR}\n"
			continue
		else
			echo -e "\e[31m*** FATAL:\e[0m Remote command to ${AMDADDR} failed. EC=$EC"
			echo -e "\e[31m*** DEBUG:\e[0m Command line: '${SSHCOMMAND}'"
			echo -e "\e[31m*** DEBUG:\e[0m Result: '${RESULT}'"
			FAIL="${FAIL}${AMDADDR}\n"
			continue
		fi

		echo -e "\e[32m*** SUCCESS:\e[0m Deployed ${DEPFILE##*/} on ${AMDADDR}."
		SUCCESS="${SUCCESS}${AMDADDR}\n"
	fi
done < <(echo -e "$AMDLIST")


#finish
echo
echo -e "deploy_keys.sh complete"
RET=0
if [[ $FAIL == "" ]]; then FAIL="(none)"; else RET=1; fi
if [[ $SUCCESS == "" ]]; then SUCCESS="(none)"; RET=1; fi
echo -e "\e[32mSuccessfully deployed to:\e[0m"
echo -e "${SUCCESS}"
echo -e "\e[31mFailed deployment to:\e[0m"
echo -e "${FAIL}"
debugecho "RET: $RET"
exit $RET

