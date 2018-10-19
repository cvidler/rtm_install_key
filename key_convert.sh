#!/bin/bash
# key_convert.sh	Convert private keys into PEM format for AMD usage
# Chris Vidler - Dynatrace DCRUM SME 2016
#

# config
DEBUG=0

# script below do not edit

OPTS=0
while getopts ":k:hds" OPT; do
	case $OPT in
		k)
			KEYFILE=$OPTARG
			OPTS=1
			;;
		h)
			;;
		d)
			DEBUG=$((DEBUG + 1))
			;;
		s)
			STDIN=" -password stdin"
			;;
		\?)
			echo "*** FATAL: Invalid argument -$OPTARG."
			exit 1
			;;
		:)
			echo "*** FATAL: argument -$OPTARG requires parameter."
			exit 1
			;;
	esac
done

if [ $OPTS -eq 0 ]; then
	echo "*** INFO: Usage: $0 [-h] [-s] -k keyfile"
    echo "-h  help"
    echo "-s  Accept openssl passwords from stdin (for scripted execution)"
	exit 0
fi



function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u`]: $1"
}




# do some rudimentary checks the file exists.
if [ $KEYFILE == foo ]; then
	techo "***FATAL: Required filename parameter missing."
	exit 1
fi

if [ ! -r $KEYFILE ]; then
	techo "*** FATAL: Key file [$KEYFILE] not readable."
	exit 1
fi


techo "Reading key: $KEYFILE"


# get extension
KEYEXT=`basename $KEYFILE`
KEYEXT=${KEYEXT##*.}
debugecho "KEYEXT: [$KEYEXT]"

case "$KEYEXT" in
	key)
		TYPE=pem
		;;
	pem)
		TYPE=pem
		;;
	der)
		TYPE=der
		;;
	pfx)
		TYPE=p12
		;;
	p12)
		TYPE=p12
		;;
	jks)
		TYPE=jks
		;;
	*)
		echo -e "*** FATAL: Unable to determine key format of $KEYFILE. Script supports only PEM, DER, JKS and P12/PFX formats"
		exit 1
		;;
esac


if [ $TYPE == jks ]; then
	# open JKS, allow user to pick a private key (multiple are possible), convert that key to a PKCS12 file, and then use the PKCS12 methods below.
	techo "Extracting key from Java Key Store format file"
	techo "***WARNING: experimental support for JKS"

	if [ ! -x "/usr/lib/jvm/jre-openjdk/bin/keytool" ]; then
		KEYTOOL=`which keytool`
		if [ $? -ne 0 ]; then techo "***FATAL Java keytool utility required for JKS extraction, not found. Aborting."; exit 1; fi
	else
		KEYTOOL="/usr/lib/jvm/jre-openjdk/bin/keytool"
	fi
	# get a list of private keys by alias, with blank password (no authenticity check, but user doesn't get prompted for anything)
	RESULTS=$(echo -e '\n' | $KEYTOOL -list -storetype jks -keystore $KEYFILE 2> /dev/null | grep -A 1 "PrivateKeyEntry" )
	NUMKEYS=0
	NUMKEYS=$(echo $RESULTS | grep "PrivateKeyEntry" | wc -l )
	if [ $NUMKEYS == 0 ]; then techo "No private keys found in JKS file [$KEYFILE], aborting."; exit 1; fi

	#extract alias names
	echo "Choose key to extract:"
	echo "#, alias, creation date, certificate fingerprint"
	IFS=','
	KEYNUM=0
	declare -a ALIASES
	while read -r a c k; do
		if [[ $a == "Certificate fingerprint"* ]]; then echo -e "${a#*:}"; continue; fi
		KEYNUM=$((KEYNUM + 1))
		echo -en "$KEYNUM: $a,$c,"
		ALIASES[$KEYNUM]=$a
	done < <(echo -e "$RESULTS")
	echo -e "Extract key #: "
	read -ei "1"
	if [ $REPLY -ge 1 ] 2> /dev/null && [ $REPLY -le $KEYNUM ] 2> /dev/null ; then
		techo "Extracting key [$REPLY]"
	else
		techo "Invalid key number entered, aborting."
		exit 1
	fi
	SRCALIAS=${ALIASES[$REPLY]}
	debugecho "ALIASES: [${ALIASES[*]}]"
	debugecho "SRCALIAS: [$SRCALIAS]"

	#extract the key, because keytool and JKS suck, convert to PKCS12 first, then let script continue on...
	techo "Converting JKS to PKCS12"
	echo -e "JKS keystore password: "
	read -se PASSWORD

	#append alias name to file name for uniqueness
	P12FILE=${KEYFILE%.*}-$SRCALIAS.p12
	keytool -importkeystore -srckeystore $KEYFILE -destkeystore $P12FILE -deststoretype PKCS12 -srcalias "$SRCALIAS" -srcstorepass "$PASSWORD" -deststorepass "$PASSWORD"
	if [ $? -ne 0 ]; then techo "JKS conversion failed. Aborting."; exit 1; fi
	PASSWORD=""

	#change type and input name, so script can carry on as if a PKCS12 file was provided.
	TYPE="p12"
	KEYFILE=$P12FILE

fi

#generate output file name
OUTFILE=${KEYFILE%.*}_decr.key
debugecho "OUTFILE: [$OUTFILE]"

if [ $TYPE == p12 ]; then
	# extract private key from pkcs12 format file
	techo "Extracting key from PKCS12 file"
	#openssl pkcs12 -in $KEYFILE -out $OUTFILE -nocerts -nodes 2> /dev/null
	openssl pkcs12 -in $KEYFILE -out $OUTFILE -clcerts -nodes $STDIN 2> /dev/null
	RESULT=$?
	if [ $RESULT -ne 0 ]; then
		techo "*** FATAL: Couldn't extract private key from PKCS12 file $KEYFILE"
		exit 1
	fi

	KEYFILE=$OUTFILE
	TYPE=pem

fi

if [ $TYPE == der ]; then
	# convert DER to PEM

	echo -e "Converting DER to PEM..."
	openssl rsa -inform $TYPE -outform PEM -in $KEYFILE -out $OUTFILE 2> /dev/null
	RESULT=$?
	if [ $RESULT -ne 0 ]; then
		techo "*** FATAL: Couldn't convert DER to PEM"
		exit 1
	fi

	KEYFILE=$OUTFILE
	TYPE=pem

fi


EXPIRY=""
#if present, examine certificate details and extract expiration date.
if [ -r ${KEYFILE%.*}.crt ]; then
	techo "Checking for certificate ${KEYFILE%.*}.crt"
	EXPIRY=`openssl x509 -noout -enddate -in ${KEYFILE%.*}.crt`
	RESULT=$?
	CN=`openssl x509 -noout -subject -nameopt oneline -in ${KEYFILE%.*}.crt`
	debugecho "CN: [$CN]"
elif [ $TYPE == "pem" ]; then
	techo "Checking PEM $KEYFILE for included certificate"
	EXPIRY=`openssl x509 -noout -enddate -in ${KEYFILE}`
	CN=`openssl x509 -noout -subject -nameopt oneline -in ${KEYFILE}`
	RESULT=$?
fi

if [ $RESULT -eq 0 ]; then
	#have an expiry date to use
	EXPIRY=${EXPIRY%%.*\=}
	debugecho "EXPIRY: [$EXPIRY]"

	EXPDATE=`date -d "${EXPIRY##*=}" +%C%y%m%d`
	debugecho "EXPDATE: [$EXPDATE]"
	EXPDATE="EXP-$EXPDATE"

	#grab CN
	CN=${CN##*CN = }
	debugecho "CN: [$CN]"
	if [ ! "$CN" == "" ]; then
		CN="CN-$CN"
	else
		CN="${KEYFILE%.*}"
	fi

	OUTFILE="${EXPDATE}-${CN}.${KEYFILE%.*}_decr.key"
	debugecho "KEYFILE: [$KEYFILE] OUTFILE: [$OUTFILE]"
fi



techo "Validating key file: $KEYFILE"

# check if it's valid using openssl
# check with a hopefully incorrect password being passed to see if it's encrypted or not, if it is the wrong password will fail, if not it'll work silently. In the odd case it is encrypted and we've got the right password it'll succeed silently, and be reported as unencrypted.
openssl rsa -check -inform $TYPE -in $KEYFILE -noout -passin pass:dummy972345uofugsoyy8wtpassword 2> /dev/null
RETURN=$?
if [ $RETURN -ne 0 ]; then
	# check without a fake password, if it's encrypted user will be prompted, otherwise it's a invalid key/wrong format etc.
	techo "Key may be encrypted."
	openssl rsa -check -inform $TYPE -in $KEYFILE -noout 2> /dev/null
	RETURN=$?
	if [ $RETURN -ne 0 ]; then
		techo "*** FATAL: $KEYFILE invalid (not RSA), wrong format (not PEM) or wrong password."
		exit 1
	fi
	techo "$KEYFILE valid, but encrypted."
	echo -n "Decrypt it? (yes|NO) "
	read YNO

	case $YNO in
		[yY] | [yY][Ee][Ss] )
			# output a decrypted key
			OUTFILE=${KEYFILE%.*}_decr.key
			openssl rsa -in $KEYFILE -outform PEM -out $OUTFILE 
			RETURN=$?
			if [ $RETURN -ne 0 ]; then
				techo "*** FATAL: Couldn't decrypt key. Wrong password?"
				exit 1	
			fi
			KEYFILE=$OUTFILE
			techo "New key file: $KEYFILE ready to install to AMD, use rtm_install_key.sh"
			exit 0
			;;
	
		*)
			techo "Not decrypting key, kpadmin will be needed to load the key into the AMD."
			exit 0
			;;
	esac
fi


techo "Complete. Saved: $KEYFILE"
exit 0

