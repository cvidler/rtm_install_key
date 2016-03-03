# rtm_install_key
Script to easily install new SSL keys on an Dynatrace DC RUM AMD

Takes a private key file, checks it for validity (correct format), and then adds it to the AMDs key repository, sets approriate permissions, and updates the key list file.
A restart is required for the new key to be used by the AMD.


## Usage
rtm_install_key.sh _privatekeyfile_

_privatekeyfile_	PEM format private key to be installed.


## Requirements
Script assumes rtm.config file is found in /usr/adlex/config/rtm.config, this is the default location, and can be changed in the script if a non-defualt installation location is used.

* bash
* openssl
* core-utils

