#!/usr/bin/env bash


if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be executed as root or using sudo."
  exit 99
fi

systemd="$(ps --no-headers -o comm 1)"
if [ ! "${systemd}" = "systemd" ]; then
  echo "This system is not running systemd.  Exiting..."
  exit 100
fi

>&2 echo "Installing script to /usr/local/sbin/..."
cp cryptmerge.sh /usr/local/sbin/cryptmerge
chmod +x /usr/local/sbin/cryptmerge

>&2 echo "Installing systemd service..."
cp cryptmerge.service /etc/systemd/system/cryptmerge.service
systemctl daemon-reload
systemctl enable cryptmerge