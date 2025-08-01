# A simple backup scheme for wallet accounts

This implements, **very likely incorrectly** the scheme introduced here:

https://delvingbitcoin.org/t/a-simple-backup-scheme-for-wallet-accounts/1607

This code is unaudited and may not securely encrypt. If you do use this to encrypt
a secret, test the decryption and remember the commit you used. That way you can
restore the secret after a breaking change.

## Usage

```sh
./backup.rb encrypt <xpub1> <xpub2> ... <descriptor>
./backup.rb decrypt <xpub> <encrypted_backup>
```

Follow instructions.

## Backup format

There's no spec for this and it may not be compatible with other implementations:

* 1 byte: number of `c_i`
* For each `c_i`:
  * 1 byte: length of `c_i`
  * N bytes: `c_i`
* 1 byte: length of `nonce`
* N bytes: `nonce`
* 1 byte: length of `auth_tag`
* N bytes: `auth_tag`
* 4 bytes: length of `encrypted_backup` (big-endian)
* N bytes: `encrypted_desc`
