# rtm_install_key
Script to easily install new SSL keys on an Dynatrace DC RUM AMD

Takes a private key file, checks it for validity (correct format), and then adds it to the AMDs key repository, sets appropriate permissions, and updates the key list file.
A restart is required for the new key to be used by the AMD.


## Usage
rtm_install_key.sh [-h] [-c _rtmconfigfile_] -k _privatekeyfile_

-h Display usage help. Optional

-c _rtmconfigfile_ Location of rtm.config if not the default. Optional

-k _privatekeyfile_	PEM format private key to be installed. Required


## Requirements
Script assumes rtm.config file is found in /usr/adlex/config/rtm.config, this is the default location, and can be changed in the script if a non-default installation location is used.

* bash
* openssl
* core-utils


# key_convert
Script to easily convert multiple key formats to PEM as required by Dynatrace DC RUM AMD.

Takes a private key file in PEM, DER, or PKCS12 (P12, PFX) format. And checks the validity of the key, and converts it to a PEM format ready for the `rtm_install_key` script.

If the provided key file is in the correct format and is valid, there'll be no output, simply a message confirming such.

If the key required conversion, the output will be a new key file in PEM format, with message detailing the new name.

*Note:* The key file name is expected to have a `.pem`, `.der`, `.pfx`, or `.p12` extension.


## Usage
key_convert.sh [-h] -k _privatekeyfile_

-h Deplay usage help. Optional

-k _privatekeyfile_ Private key to be validated/converted. Required


## Requirements

* bash
* openssl
* core-utils
 
