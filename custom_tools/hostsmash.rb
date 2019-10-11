require 'net/http'    
require 'openssl'

# todo: check if it has https:// or whatever in front of it, augment

#use: ruby hostsmash.rb https://target.com host_wordlist.txt
lines = File.read(ARGV[1])
lines.each_line do |line|
  begin
  uri = URI(ARGV[0])
  req = Net::HTTP::Get.new(uri)
  req['Host'] = line.strip
  req['X-Forwarded-For'] = line.strip
  res = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 5, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) {|http|
    http.request(req) 
  }
  puts "---- Req: #{ARGV[0]} Host: #{line.strip}"
  puts "Response code: #{res.code}"
  res.each_capitalized { |key, value| puts " - #{key}: #{value}" }
  puts res.body # <!DOCTYPE html> ... </html> => nil
  puts "--------"
  rescue Exception => ex
    puts ex.message
  end
end
