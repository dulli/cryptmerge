#! /bin/bash

echo "START of log."
 
# Read environment variables or config file (prefered if it exists) to configure the script
[ -f /etc/default/cryptmerge ] && >&2 echo "Using configuration file..." && . /etc/default/cryptmerge
if [[ -z "${CRYPTMERGE_KEY}" ]] || [[ -z "${CRYPTMERGE_URL}" ]]; then
    >&2 echo "Please provide CRYPTMERGE_KEY and CRYPTMERGE_URL as environment variables or using the configuration file"
    exit 1
fi

>&2 echo "Gathering LUKS devices to decrypt them..."
DISKTOMOUNT=( $( blkid | grep LUKS | cut --fields=1 --delimiter=: ) )

>&2 echo "Gathering fstab devices using the noauto option..."
# Change Internal Field Separator to just newlines
IFS=$'\r\n'
# Get the non-comment noauto lines from fstab, sanitized to turn whitespace into single spaces
ARR_MOUNTS=$(sed -e '/^.*#/d' -e 's/\t/ /g' /etc/fstab | awk '(index($4, "noauto") != 0)' | tr -s " ")

>&2 echo "Downloading key..."
if [[ -z "${CRYPTMERGE_USR}" ]] || [[ -z "${CRYPTMERGE_PWD}" ]]; then
    CRYPTSTRING=$(wget -qO- "${CRYPTMERGE_URL}")
else
    CRYPTSTRING=$(wget -qO- "${CRYPTMERGE_URL}" --user "${CRYPTMERGE_USR}" --password "${CRYPTMERGE_PWD}")
fi
>&2 echo "Decrypting key..."
KEYSTRING=$(echo "${CRYPTSTRING}" | openssl enc -d -aes-256-cbc -a -pbkdf2 -iter 100000 -salt -pass pass:"${CRYPTMERGE_KEY}")

for ITEM in ${DISKTOMOUNT[*]}
do
    >&2 echo "Detected LUKS device: $ITEM"
    DEVICENAME="${ITEM#/dev/}"

    >&2 echo "Trying to unlock disk $DEVICENAME..."
    echo $KEYSTRING | cryptsetup luksOpen /dev/$DEVICENAME $DEVICENAME-crypt &
    pids[${i}]=$!
done

# wait before mounting locals (ensure all drives are decrypted)
for pid in ${pids[*]}; do
    wait $pid
done

>&2 echo "All drives have been decrypted."

>&2 echo "Mounting decrypted devices..."
ARR_MOUNTS_LOCAL=$(echo "$ARR_MOUNTS" | awk '(index($3, "nfs") == 0)' | awk '(index($3, "fuse.mergerfs") == 0)' | awk '(index($4, "bind") == 0)' | cut -f1,2 -d" ")
for STR_MOUNT in ${ARR_MOUNTS_LOCAL}; do
    STR_MOUNT_POINT=`echo "${STR_MOUNT}" | cut -f2 -d" "`
    >&2 echo "Mounting $STR_MOUNT_POINT..."
    mount "$STR_MOUNT_POINT" &
    pids[${i}]=$!
done

# wait before mounting unionfs (ensure locals are mounted if used in unionfs)
for pid in ${pids[*]}; do
    wait $pid
done

>&2 echo "Mounting union filesystems..."
ARR_MOUNTS_LOCAL=$(echo "$ARR_MOUNTS" | awk '(index($3, "nfs") == 0)' | awk '(index($3, "fuse.mergerfs") != 0)' | awk '(index($4, "bind") == 0)' | cut -f1,2 -d" ")
for STR_MOUNT in ${ARR_MOUNTS_LOCAL}; do
    STR_MOUNT_POINT=`echo "${STR_MOUNT}" | cut -f2 -d" "`
    >&2 echo "Mounting mergerfs $STR_MOUNT_POINT..."
    mount "$STR_MOUNT_POINT" &
    pids[${i}]=$!
done

# wait before mounting binds (ensure locals are mounted if used in binds)
for pid in ${pids[*]}; do
    wait $pid
done

>&2 echo "Mounting binds..."
ARR_MOUNTS_BIND=$(echo "$ARR_MOUNTS" | awk '(index($3, "nfs") == 0)' | awk '(index($4, "bind") != 0)' | cut -f1,2 -d" ")
for STR_MOUNT in ${ARR_MOUNTS_BIND}; do
    STR_MOUNT_POINT=`echo "${STR_MOUNT}" | cut -f2 -d" "`
    >&2 echo "Mounting bind $STR_MOUNT_POINT..."
    mount "$STR_MOUNT_POINT" &
    pids[${i}]=$!
done

>&2 echo "All drives have been mounted."

# wait before finishing
for pid in ${pids[*]}; do
    wait $pid
done

>&2 echo "END of log."

exit 0
