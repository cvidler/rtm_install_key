#!/bin/bash
# key_convert.sh	Convert private keys into PEM format for AMD usage
# Chris Vidler - Dynatrace DCRUM SME 2016
#

# config


# script below do not edit

# grab filename from parameter
KEYFILE=${1:-foo}

# do some redimentary checks the file exists.
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
#echo $KEYEXT

case "$KEYEXT" in
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
	*)
		echo -e "*** FATAL: Unable to determine key format of $KEYFILE. Script supports only PEM, DER and P12/PFX formats"
		exit 1
		;;
esac


#generate output file name
OUTFILE=${KEYFILE%%.*}.key
#echo $OUTFILE


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



echo -e "Validating key file: $KEYFILE"

# check if it's valid using openssl
#echo -e "$TYPE format detected, checking validity with OpenSSL"
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
	echo -n "Decrypt it? (yes|NO)"
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

