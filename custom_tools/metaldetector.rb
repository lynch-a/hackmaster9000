#!/usr/bin/env ruby

# Bringing valuable secrets to the surface since 1881

require 'webrick'
require 'typhoeus'
require 'optparse'
require 'securerandom'
require 'addressable/uri'

#$stderr.reopen File.new('/dev/null', 'w')

options = {}
OptionParser.new do |opt|
  opt.on('-b', '--base http[s?]://target.com') { |o| options[:target] = o }
  opt.on('-s', '--send raw_request') { |o| options[:raw_request] = o }
end.parse!

# establish a baseline request for this target and output to file
if options.key?(:target)

response = Typhoeus.get(options[:target], verbose: true, ssl_verifypeer: false, ssl_verifyhost: 0)
uri = Addressable::URI.parse(options[:target])

puts "PORT: #{uri.port}"
File.open("web-request-#{SecureRandom.hex(6)}.txt", 'w') { |file| file.write("#{uri.to_s}\n#{response.debug_info.to_h[:header_out][0]}") }

elsif options.key?(:raw_request) # raw request was provided, send it!

  raw_http_request = options[:raw_request]

  host_payload = File.read("hosts.txt")

  request = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP)
  request.parse(StringIO.new(raw_http_request))

  # put header data into a new hash for us to modify
  header_hash = Hash.new
  request.each do |header, value|
    header_hash[header.to_sym] = value
  end

  request_method = "ERROR"

  if request.request_method == "GET"
    request_method = "get".to_sym

    parsed_query = WEBrick::HTTPUtils.parse_query(request.query_string)
    param_hash = Hash.new
    parsed_query.each do |key, value|
      param_hash[key.to_sym] = value
    end
  elsif request.request_method == "POST"
    request_method = "post".to_sym

    parsed_query = WEBrick::HTTPUtils.parse_query(request.body)
    param_hash = Hash.new
    parsed_query.each do |key, value|
      param_hash[key.to_sym] = value
    end
  end

  #header_hash["accept-encoding".to_sym] = "identity"
  #header_hash["user-agent".to_sym] = "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.142 Safari/537.36"

  host_payload.each_line do |payload|
    if payload.strip! == "ORIGINAL"
      header_hash["host"] = request["host"]
    else
      header_hash["host"] = payload
    end

    if request.request_method == "GET"
      req = Typhoeus::Request.new(
        "https://#{request.host}:#{port}#{request.path}",
        verbose: true,
        method: request_method,
        params: param_hash,
        body: request.body,
        headers: header_hash
      )
    elsif request.request_method == "POST"
      req = Typhoeus::Request.new(
        "https://#{request.host}:#{port}#{request.path}",
        method: request_method,
        body: request.body,
        headers: header_hash
      )
    end


    #puts "--- Sending Request (#{request.host}:#{request.port}#{request.path}:"
    #puts req.options
    #puts "Host: #{header_hash["host"]}"

    req.run
    response = req.response

    #puts "--- Response:"
    puts response.code
    #puts response.headers
    #puts response.body

    #require 'pp'
    #pp response.debug_info.to_h[:header_out][0]
    #exit

  end
end