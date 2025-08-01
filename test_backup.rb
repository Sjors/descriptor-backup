require 'open3'

require 'open3'
# Example descriptor with two full tpubs (randomly generated xpubs)
xpub_1 = "xpub6EdKDcsR9TK88sJ2YXBu7FWtioNP2XALkD9z5jSC4QTQvUnSYC7UHPsSH8MgwuvQxqMXN67AfmnTfHNvrZqkLbe5ob9rXw4iXp87NvxkLLN"
xpub_2 = "xpub6EdKDcsR9TK8DcZdasFrxasxxp74BdDE1KZ99hDsvyeMP61LGKhh9FxE8RieN8S77HaEhPoRvfQNFYKM3EsW19VXRcvgrk71s4VqkGQPPJS"
descriptor = "wsh(multi(2,[00000000/48h/1h/0h/2h]#{xpub_1}/<0;1>/*), multi(2,[00000001/48h/1h/0h/2h]#{xpub_2}/<0;1>/*))"

# Call encrypt
encrypt_cmd = ["ruby", "backup.rb", "encrypt", descriptor]
encrypt_out, encrypt_err, encrypt_status = Open3.capture3(*encrypt_cmd)
raise "Encrypt failed: #{encrypt_err}" unless encrypt_status.success?

# Extract backup blob from output
backup_blob = encrypt_out[/^desc1[^\n]*$/i]
unless backup_blob
  puts "DEBUG: encrypt_out was:\n#{encrypt_out}"
  raise "Failed to extract backup blob"
end
# Call decrypt
for xpub in [xpub_1, xpub_2]
  decrypt_cmd = ["ruby", "backup.rb", "decrypt", xpub, backup_blob]
  decrypt_out, decrypt_err, decrypt_status = Open3.capture3(*decrypt_cmd)
  raise "Decrypt failed: #{decrypt_err}" unless decrypt_status.success?

  # Check that decrypted descriptor matches original
  if decrypt_out.strip != descriptor.strip
    raise "Decrypted descriptor does not match original!\nExpected: #{descriptor}\nGot: #{decrypt_out.strip}"
  end

end

puts "Test passed: descriptor round-trip successful."
