#!/usr/bin/env ruby

# checks for vnc service listening on given ip/domain/port

require 'net/vnc'

if ARGV.length < 2
  puts "usage: check_vnc [ip/domain] [port] [outfilepath] [optional: path/to/wordlist]"
  exit
end

target = ARGV.shift
port = ARGV.shift
outfile_path = ARGV.shift

wordlist_path = ""
if (ARGV.length == 1)
  wordlist_path = ARGV.shift
end

flag_real = false
flag_loggedin = false
found_passwords = []

Net::VNC.const_set('BASE_PORT', port.to_i)

# try to connect to it first with no auth
puts "target: #{target} port: #{Net::VNC.const_get('BASE_PORT')}"
begin
  Net::VNC.open target, timeout: 10  do |vnc|
    flag_real = true # we got in with no auth
    flag_loggedin = true
    found_passwords << "NOAUTH"
  end
rescue Exception => ex
  puts "msg3: #{ex.message}"
  if (ex.to_s.include? "Need to authenticate") # detect if it responded and requires auth
    flag_real = true
  elsif (ex.to_s.include? "Connection refused")
    puts "No connection to #{target} #{port}"
    exit
  elsif (ex.to_s.include? "invalid server response")
    puts "Target not VNC server"
    exit
  end
end


if wordlist_path != "" and flag_loggedin == false # skip wordlist check if it worked with no auth
  pw_file = File.read("#{wordlist_path}")
  pw_file.each_line do |pw|
    next if flag_loggedin == true
    begin
      # try each pw
      Net::VNC.open target, wait: 5, password: pw  do |vnc|
        flag_real = true
        flag_loggedin = true
        found_passwords << pw.strip
        puts "found pws: #{found_passwords}"
      end
    rescue Exception => ex
      puts "msg1: #{ex.message}"
    end
  end
end

File.open(outfile_path, 'w+') { |file|
  if (flag_real and flag_loggedin)
    puts "#{target},#{port},#{found_passwords}"
    file.write("#{target},#{port},#{found_passwords}")
  elsif (flag_real)
    file.write("#{target},#{port},[]")
    puts "#{target},#{port},[]"
  end
}