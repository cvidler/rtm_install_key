# deploy_key
Script to remotely deploy (or undeploy) private key files to one or more AMDs

## Usage
`deploy_key.sh [-h] [-R|-R] [-z -z] -a amdname|amdlist -u username [-p password|-i identfile -f privatekeyfile`

Run directly on an AMD for local changes, or called automatically by `deploy_key.sh` script for remote usage.



`-h` Display usage help. Optional.

`-r` Restart rtm daemon/service for key change to take effect. Default.

`-R` DO NOT restart rtm daemon/service.

`-z -z` Remove and secure erase private key in `-k` parameter. Optional. Double -z required for safety.

`-a amdname|amdlist` Deploy to _amdname_ (ip/fqdn) or to each AMD in a line by line list file _amdlist_.

`-f privatekeyfile`	PEM format private key file to be deployed (or with -z undeployed). Required.

`-u username` Username to log onto AMD, requires root/sudo access to modify private keys.

`-i identfile` SSH private key to autologin to AMD as _username_.

`-p password` Password for _username_.



`-i` overrides `-p` as it is the more secure option.




e.g.

`./deploy_key.sh -a 192.168.93.121 -k mysitekey.key`

Deploy mysitekey.key to AMD at 192.168.93.121, use default user/password combination.

`./deploy_key.sh -a amdlist.txt -k mysitekey.key -u root -i sshkey.key`

Deploy mysitekey.key to all AMDs in amdlist.txt using root and a SSH identity (key) file.

`./deploy_key.sh -z -z -a amdlist.txt -k remove.key`

Undeploy remove.key from all AMDs in the file amdlist.txt, list file is a simple text file one AMD (by ip of fqdn) per line.



## Requirements

* bash
* ssh
* sshpass
* core-utils





# rtm_install_key
Script to easily install new SSL keys on an Dynatrace DC RUM AMD

Takes a private key file, checks it for validity (correct format), and then adds it to the AMDs key repository, sets appropriate file ownership and permissions, and updates the key list file.
A restart is required for the new key to be used by the AMD.



### Installation
Copy the scripts to your AMD server, make them executable by running:

`chmod +x rtm_install_key.sh`

`chmod +x key_convert.sh`



Installation NOT required if using `deploy_key.sh` script, it's handled automatically.



## Usage
`rtm_install_key.sh [-h] [-c rtmconfigfile] [-R|-R] [-z] -k privatekeyfile`

Run directly on an AMD for local changes, or called automatically by `deploy_key.sh` script for remote usage.



`-h` Display usage help. Optional.

`-c rtmconfigfile` Location of rtm.config if not the default. Optional.

`-r` Restart rtm daemon/service for key change to take effect. Default.

`-R` DO NOT restart rtm daemon/service.

`-z` Remove and secure erase private key in `-k` parameter. Optional.

`-k privatekeyfile`	PEM format private key to be installed. Required.



e.g.

`./rtm_install_key.sh -k mysitekey.pem`

or

`./rtm_install_key.sh -z -k remove.key`



## Requirements
Script assumes rtm.config file is found in /usr/adlex/config/rtm.config, this is the default location, and can be changed with the `-c rtmconfigfile` parameter if a non-default installation location is used.

* bash
* openssl
* core-utils


# key_convert
Script to easily convert multiple key formats to PEM as required by Dynatrace DC RUM AMD.

Takes a private key file in PEM, DER, or PKCS12 (P12, PFX) format. And checks the validity of the key, and converts it to a PEM format ready for the `rtm_install_key` script.

If the provided key file is in the correct format and is valid, there'll be no output, simply a message confirming such.

If the key required conversion, the output will be a new key file in PEM format, with message detailing the new name.

*Note:* The key file name is expected to have a `.key` `.pem`, `.der`, `.pfx`, or `.p12` extension.


## Usage
`key_convert.sh [-h] -k privatekeyfile`

`-h` Deplay usage help. Optional

`-k privatekeyfile` Private key to be validated/converted. Required

e.g.

`./key_convert.sh -k mysitekey.p12`


## Requirements

* bash
* openssl
* core-utils
 
