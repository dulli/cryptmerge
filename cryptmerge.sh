#! /bin/bash

echo "START of log."
 
# Read environment variables or config file (prefered if it exists) to configure the script
[ -f /etc/default/cryptmerge ] && >&2 echo "Using configuration file..." && . /etc/default/cryptmerge
if [[ -z "${CRYPTMERGE_KEY}" ]] || [[ -z "${CRYPTMERGE_URL}" ]]; then
    >&2 echo "Please provide CRYPTMERGE_KEY and CRYPTMERGE_URL as environment variables or using the configuration file"
    exit 1
fi

>&2 echo "Downloading and decrypting key..."
if [[ -z "${CRYPTMERGE_USR}" ]] || [[ -z "${CRYPTMERGE_PWD}" ]]; then
    CRYPTSTRING=$(wget -qO- "${CRYPTMERGE_URL}")
else
    CRYPTSTRING=$(wget -qO- "${CRYPTMERGE_URL}" --user "${CRYPTMERGE_USR}" --password "${CRYPTMERGE_PWD}")
fi
KEYSTRING=$(echo "${CRYPTSTRING}" | openssl enc -d -aes-256-cbc -a -pbkdf2 -iter 100000 -salt -pass pass:"${CRYPTMERGE_KEY}")

>&2 echo "Gathering LUKS devices to decrypt them..."
DISKTOMOUNT=( $( blkid | grep LUKS | cut --fields=1 --delimiter=: ) )
for ITEM in ${DISKTOMOUNT[*]}
do
    >&2 echo "Detected LUKS device: $ITEM"
    DEVICENAME="${ITEM#/dev/}"

    >&2 echo "Trying to unlock disk $DEVICENAME..."
    echo $KEYSTRING | cryptsetup luksOpen /dev/$DEVICENAME $DEVICENAME-crypt
done

>&2 echo "Gathering fstab devices using the noauto option..."
    # Change Internal Field Separator to just newlines
IFS=$'\r\n'
# Get the non-comment noauto lines from fstab, sanitized to turn whitespace into single spaces
ARR_MOUNTS=$(sed -e '/^.*#/d' -e 's/\t/ /g' /etc/fstab | awk '(index($4, "noauto") != 0)' | tr -s " ")

# sleep before mounting locals (ensure all drives are decrypted)
sleep 1

>&2 echo "Mounting decrypted devices..."
ARR_MOUNTS_LOCAL=$(echo "$ARR_MOUNTS" | awk '(index($3, "nfs") == 0)' | awk '(index($3, "fuse.mergerfs") == 0)' | awk '(index($4, "bind") == 0)' | cut -f1,2 -d" ")
for STR_MOUNT in ${ARR_MOUNTS_LOCAL}; do
    STR_MOUNT_POINT=`echo "${STR_MOUNT}" | cut -f2 -d" "`
    >&2 echo "Mounting $STR_MOUNT_POINT..."
    mount "$STR_MOUNT_POINT"
done

# sleep before mounting unionfs (ensure locals are mounted if used in unionfs)
sleep 1

>&2 echo "Mounting union filesystems..."
ARR_MOUNTS_LOCAL=$(echo "$ARR_MOUNTS" | awk '(index($3, "nfs") == 0)' | awk '(index($3, "fuse.mergerfs") != 0)' | awk '(index($4, "bind") == 0)' | cut -f1,2 -d" ")
for STR_MOUNT in ${ARR_MOUNTS_LOCAL}; do
    STR_MOUNT_POINT=`echo "${STR_MOUNT}" | cut -f2 -d" "`
    >&2 echo "Mounting mergerfs $STR_MOUNT_POINT..."
    mount "$STR_MOUNT_POINT"
done

# sleep before mounting binds (ensure locals are mounted if used in binds)
sleep 1

>&2 echo "Mounting binds..."
ARR_MOUNTS_BIND=$(echo "$ARR_MOUNTS" | awk '(index($3, "nfs") == 0)' | awk '(index($4, "bind") != 0)' | cut -f1,2 -d" ")
for STR_MOUNT in ${ARR_MOUNTS_BIND}; do
    STR_MOUNT_POINT=`echo "${STR_MOUNT}" | cut -f2 -d" "`
    >&2 echo "Mounting bind $STR_MOUNT_POINT..."
    mount "$STR_MOUNT_POINT"
done

>&2 echo "END of log."

exit 0