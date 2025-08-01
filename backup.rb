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
        encrypt descriptor

    "
    exit(1)
end

case ARGV[0]
    when "decrypt" then mode = Mode::DECRYPT
    when "encrypt" then mode = Mode::ENCRYPT
    else puts("Unknown command"); exit(1)
end

puts ""

cipher = OpenSSL::Cipher::AES.new(256, :GCM)

def encode_backup(pubs, c_list, nonce, auth_tag, encrypted_desc)
    backup = ""
    backup << [pubs.length].pack("C")
    c_list.each do |c_i|
        backup << [c_i.bytesize].pack("C")
        backup << c_i
    end
    backup << [nonce.bytesize].pack("C")
    backup << nonce
    backup << [auth_tag.bytesize].pack("C")
    backup << auth_tag
    backup << [encrypted_desc.bytesize].pack("N")
    backup << encrypted_desc
    backup
end

def decode_backup(backup)
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

    [c_list, nonce, auth_tag, encrypted_desc]
end

if mode == Mode::ENCRYPT then
    cipher.encrypt

    # TODO:
    # - support non-xpub keys
    descriptor = ARGV[1]

    # TODO: this parser seems to trip up on h for hardened derivations
    #       as well as other things. Extract manually instead.
    # desc = Bitcoin::Descriptor.parse(descriptor)
    # xpubs = desc.keys.map(&:origin).map(&:key).uniq

    # Extract all xpubs (and tpubs, etc. if needed)
    xpubs = descriptor.scan(/\b[xvt]pub[a-zA-Z0-9]{107,108}\b/).uniq

    # Also extract xprv/tprv, convert to xpub, and add to xpubs
    descriptor.scan(/\b[xvt]prv[a-zA-Z0-9]{107,108}\b/).uniq.each do |xprv|
        begin
            ext_prv = Bitcoin::ExtKey.from_base58(xprv)
            xpub = ext_prv.ext_pubkey.to_base58
            unless xpubs.include?(xpub)
                xpubs << xpub
                puts "Converted #{xprv[0..6]}... to #{xpub[0..6]}... and added to xpubs"
            end
        rescue => e
            puts "Failed to convert #{xprv[0..7]}... to xpub: #{e}"
            exit(1)
        end
    end

    pubs = []
    xpubs.each do |xpub|
        ext_pubkey = Bitcoin::ExtPubkey.from_base58(xpub)
        pubs << hex_to_bin(ext_pubkey.pub)
    end
    pubs.sort!

    s = Digest::SHA2.digest("BACKUP_DECRYPTION_SECRET" + pubs.join())
    cipher.key = s
    nonce = OpenSSL::Random.random_bytes(12)
    cipher.iv = nonce
    cipher.auth_data = ""

    encrypted_desc = cipher.update(descriptor) + cipher.final

    c_list = []
    pubs.each_with_index do |pub, i|
        s_i = Digest::SHA2.digest("BACKUP_INDIVIDUAL_SECRET" + pub)
        c_i = xor_bytes(s, s_i)
        c_list << c_i
    end

    backup = encode_backup(pubs, c_list, nonce, cipher.auth_tag(), encrypted_desc)

    puts "The following xpubs can be used to decrypt the backup:"
    xpubs.each do |xpub|
        puts "- #{xpub}"
    end
    puts ""
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
    c_list, nonce, auth_tag, encrypted_desc = decode_backup(backup)

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
