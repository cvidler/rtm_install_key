#!/bin/bash
# key_convert.sh	Convert private keys into PEM format for AMD usage
# Chris Vidler - Dynatrace DCRUM SME 2016
#

# config
DEBUG=0

# script below do not edit

OPTS=0
while getopts ":k:hd" OPT; do
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
	echo "*** INFO: Usage: $0 [-h] -k keyfile"
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
	echo -e "***FATAL: Required filename parameter missing."
	exit 1
fi

if [ ! -r $KEYFILE ]; then
	echo -e "*** FATAL: Key file: $KEYFILE not readable."
	exit 1
fi


echo -e "Reading key: $KEYFILE"


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


#generate output file name
OUTFILE=${KEYFILE%%.*}.key
debugecho "OUTFILE: [$OUTFILE]"

if [ $TYPE == jks ]; then
	echo -e "Extracting key from Java Key Store format file"
	echo -e "***WARNING: experimental support"

	exit 1
fi

if [ $TYPE == p12 ]; then
	# extract private key from pkcs12 format file
	echo -e "Extracting key from PKCS12 file"
	openssl pkcs12 -in $KEYFILE -out $OUTFILE -nocerts -nodes 2> /dev/null
	RESULT=$?
	if [ $RESULT -ne 0 ]; then
		echo -e "*** FATAL: Couldn't extract private key from PKCS12 file $KEYFILE"
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
		echo -e "*** FATAL: Couldn't convert DER to PEM"
		exit 1
	fi

	KEYFILE=$OUTFILE
	TYPE=pem

fi


if [ -r $KEYFILE.crt ]; then
	#if present, examin certificate details and extract expiration date.
	echo -e "Checking for certificate $KEYFILE.crt"
	EXPIRY=$(openssl x509 -text -in $KEYFILE.crt | grep "Not After : ")
	debugecho "EXPIRY: [$EXPIRY]"
fi

echo -e "Validating key file: $KEYFILE"

# check if it's valid using openssl
# check with a hopefully incorrect password being passed to see if it's encrypted or not, if it is the wrong password will fail, if not it'll work silently. In the odd case it is encrypted and we've got the right password it'll succeed silently, and be reported as unencrypted.
openssl rsa -check -inform $TYPE -in $KEYFILE -noout -passin pass:dummy972345uofugsoyy8wtpassword 2> /dev/null
RETURN=$?
if [ $RETURN -ne 0 ]; then
	# check without a fake password, if it's encrypted user will be prompted, otherwise it's a invalid key/wrong format etc.
	echo -e "Key may be encrypted."
	openssl rsa -check -inform $TYPE -in $KEYFILE -noout 2> /dev/null
	RETURN=$?
	if [ $RETURN -ne 0 ]; then
		echo -e "*** FATAL: $KEYFILE invalid or wrong password."
		exit 1
	fi
	echo -e "$KEYFILE valid, but encrypted."
	echo -n "Decrypt it? (yes|NO) "
	read YNO

	case $YNO in
		[yY] | [yY][Ee][Ss] )
			# output a decrypted key
			OUTFILE=${KEYFILE%%.*}_decr.key
			openssl rsa -in $KEYFILE -outform PEM -out $OUTFILE -noout  
			RETURN=$?
			if [ $RETURN -ne 0 ]; then
				echo -e "*** FATAL: Couldn't decrypt key. Wrong password?"
				exit 1	
			fi
			KEYFILE=$OUTFILE
			echo -e "New key file: $KEYFILE ready to install to AMD, use rtm_install_key.sh"
			exit 0
			;;
	
		*)
			echo -e "Not decrypting key, kpadmin will be needed to load the key into the AMD."
			exit 0
			;;
	esac
fi


echo -e "Complete. Saved: $KEYFILE"
exit 0

