# A simple backup scheme for wallet accounts

This implements, **very likely incorrectly** the scheme introduced here:

https://delvingbitcoin.org/t/a-simple-backup-scheme-for-wallet-accounts/1607

This code is unaudited and may not securely encrypt. If you do use this to encrypt
a secret, test the decryption and remember the commit you used. That way you can
restore the secret after a breaking change.

## Usage

```sh
./backup.rb encrypt <descriptor>
./backup.rb decrypt <xpub> <encrypted_backup>
```

Follow instructions.

## Example

Encrypt a multisig descriptor:

```sh
./backup.rb encrypt "tr(musig(xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL,xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y)/0/*)"

The following xpubs can be used to decrypt the backup:
- xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL
- xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y

--------------------------- your backup -----------------------------------
desc1qgs93fmx4x8y2tnh5z44g3z86pl5m49xxsv670p204glqr27sq4sf73q9rm243vgu743u27exuk0y00kmx6euk3fv669huj9q5t0dy7ah4hse5g0vzuhphl6dnpenusyzr45g77mahu7am0hmzmx82evychqqqqqamm0ptfw2k3xjaxzjlxyjckxsxta7a9l37v9zptgy8cl7kajqgr5jpf0jlc82h3scu00g82asynx00v7v3v9s0dunzlz5057ayhjnn6g74md67vhchz4vntwk3kwp8rt87wr63zndqaj4egghaceng7twqjqzf65f6fykcwac06tl5577g248rz2gyvfewsfj3rd8gv2jn7aeral9g6m76y3ndwqmlmgm9uvheeqtd8nu5pdeg2ndnmhmq889wnh0sl0uqylnuw9alz98sag4y9fvtwt0k2jlplxkp7xkj348kj64ydd823hxqgeptz7yne548zsyerqdygxdepzsvcwenv6d34w9k2egur762fxyql8ew3xc8kke9pwxlqgkurlh
---------------------------------------------------------------------------
```

Either participant can decrypt it:

```sh
./backup.rb decrypt xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL desc1qgs93fmx4x8y2tnh5z44g3z86pl5m49xxsv670p204glqr27sq4sf73q9rm243vgu743u27exuk0y00kmx6euk3fv669huj9q5t0dy7ah4hse5g0vzuhphl6dnpenusyzr45g77mahu7am0hmzmx82evychqqqqqamm0ptfw2k3xjaxzjlxyjckxsxta7a9l37v9zptgy8cl7kajqgr5jpf0jlc82h3scu00g82asynx00v7v3v9s0dunzlz5057ayhjnn6g74md67vhchz4vntwk3kwp8rt87wr63zndqaj4egghaceng7twqjqzf65f6fykcwac06tl5577g248rz2gyvfewsfj3rd8gv2jn7aeral9g6m76y3ndwqmlmgm9uvheeqtd8nu5pdeg2ndnmhmq889wnh0sl0uqylnuw9alz98sag4y9fvtwt0k2jlplxkp7xkj348kj64ydd823hxqgeptz7yne548zsyerqdygxdepzsvcwenv6d34w9k2egur762fxyql8ew3xc8kke9pwxlqgkurlh

tr(musig(xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL,xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y)/0/*)
```

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

The result is bech32m encoded with "desc" as the human readable part.
