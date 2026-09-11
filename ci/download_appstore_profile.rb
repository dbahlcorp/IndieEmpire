#!/usr/bin/env ruby

require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"

key_path, key_id, issuer_id, profile_id, output_path = ARGV
abort "usage: download_appstore_profile.rb KEY_PATH KEY_ID ISSUER_ID PROFILE_ID OUTPUT_PATH" unless output_path

def base64url(value)
  Base64.urlsafe_encode64(value, padding: false)
end

issued_at = Time.now.to_i
header = base64url(JSON.generate(alg: "ES256", kid: key_id, typ: "JWT"))
payload = base64url(JSON.generate(iss: issuer_id, iat: issued_at, exp: issued_at + 600, aud: "appstoreconnect-v1"))
unsigned_token = "#{header}.#{payload}"

private_key = OpenSSL::PKey.read(File.binread(key_path))
digest = OpenSSL::Digest::SHA256.digest(unsigned_token)
der_signature = private_key.dsa_sign_asn1(digest)
raw_signature = OpenSSL::ASN1.decode(der_signature).value.map do |integer|
  integer.value.to_s(2).rjust(32, "\0")
end.join
token = "#{unsigned_token}.#{base64url(raw_signature)}"

uri = URI("https://api.appstoreconnect.apple.com/v1/profiles/#{profile_id}")
request = Net::HTTP::Get.new(uri)
request["Authorization"] = "Bearer #{token}"
response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
abort "Apple profile download failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

profile_content = JSON.parse(response.body).dig("data", "attributes", "profileContent")
abort "Apple profile response did not contain profileContent" if profile_content.nil? || profile_content.empty?

File.binwrite(output_path, Base64.decode64(profile_content))
puts "Downloaded provisioning profile (#{File.size(output_path)} bytes)."
