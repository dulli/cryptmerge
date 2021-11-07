# CryptMerge (WIP)

Setting up a combination of `LUKS` encrypted disks and a `mergerfs` union filesystem, to pool the storage on those encrypted disks, on an unsupervised system like a `NAS` (in this case with OMV[^0]) leads to failed boots, because the encryption key can not be provided manually on boot and the auto-mount procedure will time out. Therefore the pool storage's dependencies never become accessible. One way to circumvent this, without jeopardizing security too much is the following, which uses a combination of existing approaches to perform the decryption with a key stored on a remote system[^1] and then manually triggering a script that automatically mounts all remaining drives[^2] and adds an additional encryption layer:

- All `LUKS` encrypted disks and the `mergerfs` pool must have `noauto` added in `/etc/fstab`
- This needs to be done so that the boot doesn't fail and is the easiest way to avoid waiting on the default timeout
- The decryption is performed after boot, i.e. the disks as well as the `mergerfs` pool have to be mounted after boot
- To perform this automatically and to circumvent the need to enter the encryption key on each boot, the key is stored on a remote server and fetched via HTTP(S)
- Additionally, the remote key is stored encrypted and the decryption password is stored on the local machine
- Without knowledge of both these secrets, i.e. access to both machines, the disks can't be decrypted

## Install

Run the following commands (prepend `sudo`, if you are not `root`) to make the script executable and auto-install it as service running at late-startup:

```bash
chmod +x cryptmerge
update-rc.d cryptmerge defaults
```

### Generate Keyfile

To generate the encrypted contents for the key file that will be placed on the remote host run

```bash
CRYPTMERGE_KEY="somekey" ./tools/encode.sh
```

and then enter your encryption key in the prompt. The tool will output the encrypted key to `STDOUT`. Copy it or pipe it to a file.

### Config

All configuration is handled through environment variables. However, if using the script as a startup service as intended, these may not be available yet. Therefore the variables can also be defined using a file located at `/etc/default/cryptmerge`. If the configuration file exist, its content will be preferred over defined environment variables (effectively overriding them).

Required configuration variables are `CRYPTMERGE_KEY`, defining the encryption passphrase used for the remote key file, and `CRYPTMERGE_URL`, which defines its location:

```bash
CRYPTMERGE_KEY="somekey"
CRYPTMERGE_URL="192.168.0.1/keyfile.txt"
```

Optional variables allow for the use of HTTP Basic Auth, if the remote host requires it:

```bash
CRYPTMERGE_USR="someuser"
CRYPTMERGE_PWD="somepassword"
```

## Does the key encryption on the remote host actually increase security?

Well, not really? At least not against local attackers: If you have the unencrypted key but no access to the local host, it won't be of any use to you. And as soon as you have access to the local host, you can decrypt it.

It does protect against other machines being compromised if you are re-using keys (which you of course shouldn't be doing anyways), and allows for invalidation of the remote key by changing the local passphrase. Also, edge cases could exist, where an attacker has remote access to the OMV web GUI and the remote key, or access to the encrypted disks and the network traffic, especially in local networks where HTTPS certificates are non-trivial, but not the system drive of the local machine...  
So, **TL;DR:** using this additional encryption step as a security measure is a stretch, but also not hard to implement so why not just do it.

## Project goals and to-dos

- [x] Implement the automatic LUKS decryption
- [x] Implement the automatic mounting of `noauto` `fstab`-entries
- [x] Add encryption to the remote key
- [x] Add HTTP Basic Auth
- [ ] Testing
- [ ] Create the install script
- [ ] _Optional_: Create a simple backend/API that automates the remote key storage and deletion

## References

[^0]: [`openmediavault: The open network attached storage solution`](https://www.openmediavault.org/)
[^1]: [`Automount LUKS disk using remote key`](https://goodstone.altervista.org/wiki/doku.php?id=linux:openmediavault:automount_luks_with_remote_key)
[^2]: [`github.com/longranger/noauto_mounter`](https://github.com/longranger/noauto_mounter/blob/master/noauto_mounter)
