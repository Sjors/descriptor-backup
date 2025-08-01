#!/usr/bin/env ruby

require 'base64'
require 'bitcoin'
require 'digest'
require 'openssl'

class Mode
    DECRYPT = 0
    ENCRYPT = 1
end

def hex_to_bin(hex)
    [hex].pack("H*")
end

def xor_bytes(a, b)
    a.bytes.zip(b.bytes).collect { |x, y| x ^ y }.pack("c*")
end

mode = nil

if ARGV.empty?
    puts "
    Usage: backup.rb <command>

    Commands:
        decrypt xpub c1 ... nonce auth encrypted_data
        encrypt xpub1 xpub2 xpub3 ... descriptor

    "
    exit(1)
end

case ARGV[0]
    when "decrypt" then mode = Mode::DECRYPT
    when "encrypt" then mode = Mode::ENCRYPT
    else puts("Unknown command"); exit(1)
end

cipher = OpenSSL::Cipher::AES.new(256, :GCM)

if mode == Mode::ENCRYPT then
    cipher.encrypt

    # TODO:
    # - also support BIP388 policy and key list
    descriptor = ARGV[-1]
    # TODO:
    # - get xpubs from the descriptor
    # - convert any xprv to xpub
    # - support non-xpub keys
    xpubs = ARGV[1..-2]
    pubs = []
    for xpub in xpubs do
        ext_pubkey = Bitcoin::ExtPubkey.from_base58(xpub)
        pubs.append hex_to_bin(ext_pubkey.pub)
    end
    pubs.sort

    s = Digest::SHA2.digest("BACKUP_DECRYPTION_SECRET" + pubs.join())
    cipher.key = s
    nonce = OpenSSL::Random.random_bytes(12)
    cipher.iv = nonce
    cipher.auth_data = ""

    encrypted_desc = cipher.update(descriptor) + cipher.final

    puts
    puts "--------------------------- backup all of this ---------------------------"

    pubs.each_with_index do |pub, i|
        s_i = Digest::SHA2.digest("BACKUP_INDIVIDUAL_SECRET" + pub)
        c_i = xor_bytes(s, s_i).unpack("H*").first
        puts "c_#{i + 1}:      #{ c_i }"
    end

    puts "nonce:    #{ nonce.unpack("H*").first }"
    puts "auth tag: #{ cipher.auth_tag().unpack("H*").first }"

    puts Base64.strict_encode64(encrypted_desc)
    puts "---------------------------------------------------------------------------"

    # TODO:
    # - design format that combines the encrypted payload, nonce, auth and list of c_
else
    cipher.decrypt

    xpub = ARGV[1]
    ext_pubkey = Bitcoin::ExtPubkey.from_base58(xpub)
    s = Digest::SHA2.digest("BACKUP_INDIVIDUAL_SECRET" + hex_to_bin(ext_pubkey.pub))
    for share in ARGV[2..-4] do
        c_i = hex_to_bin(share)
        key = xor_bytes(s, c_i)

        cipher.key = key
        cipher.iv = hex_to_bin(ARGV[-3])
        cipher.auth_tag = hex_to_bin(ARGV[-2])
        cipher.auth_data = ""
        begin
            puts cipher.update(Base64.decode64(ARGV[-1])) + cipher.final
            exit(0)
        rescue OpenSSL::Cipher::CipherError
        end
    end
    puts "Decryption failed"
    exit(1)
end
