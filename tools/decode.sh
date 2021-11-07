#!/usr/bin/env bash

[ -f /etc/default/cryptmerge ] && echo "Using configuration file..." && . /etc/default/cryptmerge
if [[ -z "${CRYPTMERGE_KEY}" ]] || [[ -z "${CRYPTMERGE_URL}" ]]; then
    echo "Please provide CRYPTMERGE_KEY and CRYPTMERGE_URL as environment variables or using the configuration file"
    exit 1
fi

if [[ -z "${CRYPTMERGE_USR}" ]] || [[ -z "${CRYPTMERGE_PWD}" ]]; then
    CRYPTSTRING=$(wget -qO- "${CRYPTMERGE_URL}")
else
    CRYPTSTRING=$(wget -qO- "${CRYPTMERGE_URL}" --user "${CRYPTMERGE_USR}" --password "${CRYPTMERGE_PWD}")
fi
KEYSTRING=$(echo "${CRYPTSTRING}" | openssl enc -d -aes-256-cbc -a -pbkdf2 -iter 100000 -salt -pass pass:"${CRYPTMERGE_KEY}")

echo "Received secret: $KEYSTRING"