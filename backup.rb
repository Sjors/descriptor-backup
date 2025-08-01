#!/usr/bin/env ruby

require 'base64'
require 'bitcoin'
require 'digest'
require 'openssl'

class Mode
    DECRYPT = 0
    ENCRYPT = 1
end

def bin_to_hex(bin)
    bin.unpack("H*").first
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

    backup = ""
    backup << [pubs.length].pack("C")
    c_list = []
    pubs.each_with_index do |pub, i|
        s_i = Digest::SHA2.digest("BACKUP_INDIVIDUAL_SECRET" + pub)
        c_i = xor_bytes(s, s_i)
        backup << [c_i.bytesize].pack("C")
        backup << c_i
        c_list << c_i
    end

    backup << [nonce.bytesize].pack("C")
    backup << nonce

    auth_tag = cipher.auth_tag()
    backup << [auth_tag.bytesize].pack("C")
    backup << auth_tag

    backup << [encrypted_desc.bytesize].pack("N")
    backup << encrypted_desc

    puts
    puts "--------------------------- your backup -----------------------------------"
    puts Bitcoin::Base58.encode(bin_to_hex(backup))
    puts "---------------------------------------------------------------------------"


else
    cipher.decrypt

    if ARGV.length != 3
        puts "Usage: backup.rb decrypt <xpub> <encrypted_backup>"
        exit(1)
    end

    xpub = ARGV[1]
    backup = hex_to_bin(Bitcoin::Base58.decode(ARGV[2]))
    offset = 0

    num_c = backup[offset].ord
    offset += 1

    c_list = []
    num_c.times do
        len = backup[offset].ord
        offset += 1
        c_i = backup[offset, len]
        offset += len
        c_list << c_i
    end

    nonce_len = backup[offset].ord
    offset += 1
    nonce = backup[offset, nonce_len]
    offset += nonce_len

    auth_tag_len = backup[offset].ord
    offset += 1
    auth_tag = backup[offset, auth_tag_len]
    offset += auth_tag_len

    enc_desc_len = backup[offset, 4].unpack1("N")
    offset += 4
    encrypted_desc = backup[offset, enc_desc_len]
    offset += enc_desc_len

    ext_pubkey = Bitcoin::ExtPubkey.from_base58(xpub)
    s = Digest::SHA2.digest("BACKUP_INDIVIDUAL_SECRET" + hex_to_bin(ext_pubkey.pub))

    c_list.each do |c_i|
        key = xor_bytes(s, c_i)
        cipher.key = key
        cipher.iv = nonce
        cipher.auth_tag = auth_tag
        cipher.auth_data = ""
        begin
            puts cipher.update(encrypted_desc) + cipher.final
            exit(0)
        rescue OpenSSL::Cipher::CipherError
            # Try next c_i
        end
    end
    puts "Decryption failed"
    exit(1)
end
