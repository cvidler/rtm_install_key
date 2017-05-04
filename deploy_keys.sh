#! /bin/bash
#
# deploy_keys.sh
# Chris Vidler - Dynatrace DCRUM SME - 2016
# Deploy SSL private keys to remote AMDs
#

#script defaults

#default build AMD credentials
DEPUSER="root"
DEPPASS="greenmouse"
#specify a default ident file for your environment below
IDENT=""

#temp path on the AMD to copy files to
DEPPATH="/tmp"
#script to copy and run on the AMD
DEPSCRIPT="rtm_install_key.sh"
#default execute the deploy script on the AMD
DEPEXEC=1
#default restart rtm daemon
RESTART=1


#script follows do not edit.
set -e

function debugecho {
	LVL=${2:-1}
	if test $DEBUG -ge $LVL ; then techo "\e[2m***DEBUG[${LVL}]:\e[0m $1"; fi
}

function fatalecho {
	LVL=${2:-1}
	if [[ $DEBUG -ne 0 ]]; then techo "\e[31m***FATAL: $1\e[0m" >&2; exit 1; fi
}

function warningecho {
	LVL=${2:-1}
	if [[ $DEBUG -ne 0 ]]; then techo "\e[33m***WARNING: $1\e[0m"; fi
}

function setdebugecho {
	if [[ $DEBUG -ne 0 ]]; then echo -ne "\e[2m"; fi
}

function unsetdebugecho {
	if [[ $DEBUG -ne 0 ]]; then echo -ne "\e[0m"; fi
}

function techo {
	echo -e "[`date -u`]: $1"
}



#command line parameters
#preset defaults
UNDEPLOY=0
HITS=0
OPTS=0
while getopts ":hdrRf:a:u:p:i:x:z" OPT; do
	case $OPT in
		h)
			OPTS=0	#show help
			;;
		d)
			DEBUG=$((DEBUG + 1))
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
				fatalecho "Identity file [$OPTARG] not present or inaccessible."
			fi
			;;
		x)
			OPTS=1
			RUNCMD=$OPTARG
			;;
		z)
			if [ $HITS -eq 1 ]; then
				OPTS=1
				HITS=3
				UNDEPLOY=1
				RESTART=0
			else
				HITS=$((HITS + 1))
			fi
			;;
		\?)
			OPTS=0 #show help
			warningecho "Invalid argument [-$OPTARG]."
			;;
		:)
			OPTS=0 #show help
			warningecho "argument [-$OPTARG] requires parameter."
			;;
	esac
done

#abort, showing help, if required options are unset
if [ "$DEPFILE" == "" ]; then OPTS=0; fi
if [ "$AMDADDR" == "" ]; then OPTS=0; fi
#debugecho $HITS
if [ $HITS -gt 0 ] && [ $HITS -lt 3 ]; then OPTS=0; fi

#check for required script file
if [ ! -r $DEPSCRIPT ]; then
	fatalecho "Required script [$DEPSCRIPT] not found or inaccessible."
fi


if [ $OPTS -eq 0 ]; then
	echo -e "*** INFO: Usage: $0 [-h] [-R|r] [-z -z] -a amdaddress|listfile -f privatekey [-u user] [-p password | -i identfile]"
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
	echo -e "		Live reload will be used if possible (ver 17+)."
	echo -e "-R 	DO NOT Restart rtm process once copied."
	echo -e ""
	echo -e "-z -z	undeploy/remove (and secure erase) private key named in '-f privatekey' parameter. Requires double -z for safety."
	echo -e ""
	echo -e "-p and -i are exclusive, -i takes precedence as it is more secure."
	exit 0
fi

#check if passed file is readable.
if [ ! -r $DEPFILE ]; then
	if [ ! "$UNDEPLOY" == "1" ]; then
		fatalecho "Deploy file $DEPFILE not present or inaccessible."
	else
		debugecho "Deploy file $DEPFILE not present or inaccessible."
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

		if [[ $line =~ [aA],https?:\/\/.*@([a-zA-Z0-9.-]+):[0-9]+ ]]; then					# queryrumc.sh output file format
			line=`expr match "$line" '[aA],https\?://.*@\([a-zA-A0-9.-]\+\):[0-9]\+'`		# extract name using regex
			AMDLIST="$AMDLIST$line\n"
			continue
		elif [[ $line =~ [dD],https?:\/\/.*@([a-zA-Z0-9.-]+):[0-9]+ ]]; then
			continue
		fi

		if [[ $line =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|[a-zA-Z0-9\.-]+|\[?[0-9a-fA-F:]+\]?)$ ]]; then		#rudimentary ip/fqdn/ipv6 test
			AMDLIST="$AMDLIST$line\n"
			continue
		fi

		debugecho "AMDLIST nonmatching line: ${line}"
	done < <(cat $AMDADDR)
	AMDLIST=${AMDLIST%%\\n}		#remove trailing comma
else
	#it's not a list file. nothing to do.
	AMDLIST=$AMDADDR
fi


debugecho "Configuration:"
debugecho "DEPUSER: [$DEPUSER], DEPPASS: [$DEPPASS], IDENT: [$IDENT], AMDADDR: [$AMDADDR], DEPSCRIPT: [$DEPSCRIPT] "
debugecho "DEPPATH: [$DEPPATH], RESTART: [$RESTART], RESTARTSCHED: [$RESTARTSCHED], DEPEXEC: [$DEPEXEC] "
debugecho "UNDEPLOY: [$UNDEPLOY], DEPFILE: [$DEPFILE]"
debugecho "AMDLIST: [$AMDLIST] "

#get dependencies for config
SCP=`which scp`
if [ $? -ne 0 ]; then
	fatalecho "Dependency 'scp' not found."
fi
SSH=`which ssh`
if [ $? -ne 0 ]; then
	fatalecho "Dependency 'ssh' not found."
fi
debugecho "SCP: [$SCP], SSH: [$SSH] "


#build configs
if [ $DEBUG -ge 2 ]; then VERBOSE=" -v"; fi		#in debug 3+ mode add verbosity to SCP and SSH commands later on

#DEPPASS="$DEPPASS"
if [ ! "$IDENT" == "" ]; then 
	# if ident file to be used clear any default or user set password.
	DEPPASS=""
else
	# if user supplied password is required, need to use 'sshpass' to automatically pass it to both SCP and SSH.
	SSHPASSE=`which sshpass`
	if [ $? -ne 0 ]; then
		fatalecho "Dependency 'sshpass' not found."
	fi
	debugecho "SSHPASSE: [$SSHPASSE]", 2
	SSHPASS=${DEPPASS}
	DEPPASS="${SSHPASSE} -e "
	debugecho "SSHPASS: [$SSHPASS]", 2
	debugecho "DEPPASS: [$DEPPASS]", 2
fi

if [[ $RESTART = 1 ]]; then RESTART="-r"; else RESTART="-R"; fi
if [[ $DEBUG -ge 1 ]]; then DBG="-d "; else DBG=""; fi


if [ ! -x $DEPSCRIPT ]; then chmod +x $DEPSCRIPT; debugecho "chmod +x to [$DEPSCRIPT]"; fi
if [ $UNDEPLOY -eq 1 ]; then STS="Removed"; else STS="Deployed"; fi

SUCCESS=""
FAIL=""

while read line; do

	AMDADDR=$line
	techo "\e[34mdeploy_keys.sh\e[0m Deploying ${DEPFILE##*/} to ${AMDADDR}"

	#build SCP command line
	if [ "$UNDEPLOY" == "1" ]; then
		SCPCOMMAND="${DEPPASS}${SCP}${VERBOSE} -p${IDENT} $DEPSCRIPT ${DEPUSER}@${AMDADDR}:${DEPPATH}"
	else
		SCPCOMMAND="${DEPPASS}${SCP}${VERBOSE} -p${IDENT} $DEPSCRIPT ${DEPFILE} ${DEPUSER}@${AMDADDR}:${DEPPATH}"
	fi
	debugecho "SCPCOMMAND: [$SCPCOMMAND]"

	#export envvar for sshpass
	export SSHPASS=$SSHPASS

	#run SCP command
	setdebugecho
	RESULT=`$SCPCOMMAND`
	EC=$?
	unsetdebugecho
	if [[ $EC -ne 0 ]]; then
		techo "\e[31m*** FATAL:\e[0m SCP to [${AMDADDR}] failed."
		FAIL="${FAIL}${AMDADDR}\n"
		continue
	fi
	techo "\e[32m*** SUCCESS:\e[0m Copied [${DEPFILE##*/}] to [${AMDADDR}]."
	if [ $DEPEXEC == 0 ]; then SUCCESS="${SUCCESS}${AMDADDR}\n"; fi

	#build SSH command line to run copied file
	if [ "$DEPEXEC" == "1" ]; then
		if [ "$UNDEPLOY" == "1" ]; then
			SSHCOMMAND="${DEPPASS}${SSH}${VERBOSE} -tt${IDENT} ${DEPUSER}@${AMDADDR} ${DEPPATH}/${DEPSCRIPT##*/} ${DBG}-s -l -z ${RESTART} -k ${DEPFILE##*/}"
		else
			SSHCOMMAND="${DEPPASS}${SSH}${VERBOSE} -tt${IDENT} ${DEPUSER}@${AMDADDR} ${DEPPATH}/${DEPSCRIPT##*/} ${DBG}-s -l ${RESTART} -k ${DEPPATH}/${DEPFILE##*/}"
		fi
		debugecho "SSHCOMMAND: [$SSHCOMMAND]"

		#run SSH command
		setdebugecho
		RESULT=""
		RESULT=`$SSHCOMMAND`
		EC=$?
		unsetdebugecho
		debugecho "---ssh-result---\n$RESULT\n---ssh-result---" 2
		if [ $EC == 0 ]; then
			echo -n
		elif [ $EC == 255 ]; then
			techo "\e[31m*** FATAL:\e[0m SSH to [${AMDADDR}] failed. EC: [$EC]"
			FAIL="${FAIL}${AMDADDR}\n"
			continue
		else
			techo "\e[31m*** FATAL:\e[0m Remote command to [${AMDADDR}] failed. EC: [$EC]"
			techo "\e[31m*** DEBUG:\e[0m Command line: [${SSHCOMMAND}]"
			techo "\e[31m*** DEBUG:\e[0m Result: [${RESULT}]"
			FAIL="${FAIL}${AMDADDR}\n"
			continue
		fi

		techo "\e[32m*** SUCCESS:\e[0m ${STS} ${DEPFILE##*/} on ${AMDADDR}."
		SUCCESS="${SUCCESS}${AMDADDR}\n"
	fi
done < <(echo -e "$AMDLIST")


#finish
echo
techo "deploy_keys.sh complete"
RET=0
if [[ $FAIL == "" ]]; then FAIL="(none)"; else RET=1; fi
if [[ $SUCCESS == "" ]]; then SUCCESS="(none)"; RET=1; fi
techo "\e[32mSuccessfully ${STS} on:\e[0m"
techo "${SUCCESS}"
techo "\e[31mFailed on:\e[0m"
techo "${FAIL}"
debugecho "RET: [$RET]"
exit $RET

