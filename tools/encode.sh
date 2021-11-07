#!/usr/bin/env bash

[ -f /etc/default/cryptmerge ] && >&2 echo "Using configuration file..." && . /etc/default/cryptmerge
if [[ -z "${CRYPTMERGE_KEY}" ]]; then
    >&2 echo "Please provide CRYPTMERGE_KEY as environment variables or using the configuration file"
    exit 1
fi

>&2 echo "Enter the encryption key"
read ENC_KEY

CRYPTSTRING=$(echo $ENC_KEY | openssl enc -e -aes-256-cbc -a -pbkdf2 -iter 100000 -salt -pass pass:"${CRYPTMERGE_KEY}")

>&2 echo "Please copy the encrypted key and store it on your remote host:"
echo $CRYPTSTRING