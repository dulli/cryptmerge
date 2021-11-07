#!/usr/bin/env bash

[ -f /etc/default/cryptmerge ] && echo "Using configuration file..." && . /etc/default/cryptmerge
if [[ -z "${CRYPTMERGE_KEY}" ]]; then
    echo "Please provide CRYPTMERGE_KEY as environment variables or using the configuration file"
    exit 1
fi

echo "Enter the encryption key"
read ENC_KEY
echo $ENC_KEY

CRYPTSTRING=$(echo $ENC_KEY | openssl enc -e -aes-256-cbc -a -pbkdf2 -iter 100000 -salt -pass pass:"${CRYPTMERGE_KEY}")

echo $CRYPTSTRING