# A simple backup scheme for wallet accounts

This implements, **very likely incorrectly** the scheme introduced here:

https://delvingbitcoin.org/t/a-simple-backup-scheme-for-wallet-accounts/1607

This code is unaudited and may not securely encrypt. If you do use this to encrypt
a secret, test the decryption and remember the commit you used. That way you can
restore the secret after a breaking change.

## Usage

./backup.rb

Follow instructions.
