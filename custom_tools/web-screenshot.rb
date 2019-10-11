#!/usr/bin/env ruby

# takes a domain name or ip address

# tries to pull a screenshot of:
# http://domain.com:80
# https://domain.com:443

require 'net/http'
require 'uri'
require 'gastly'
require 'openssl'
require 'securerandom'

if (ARGV.length < 2)
  puts "Use: screenshot.rb outfile.txt [list of domain names or ips (or mixed)]"
  exit
end

output = ARGV.shift
#ss_dir = ARGV.shift
targets = ARGV

def url_exist?(url_string)
  begin
    url = URI.parse(url_string)
    req = Net::HTTP.new(url.host, url.port)
    req.use_ssl = (url.scheme == 'https')
    req.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req.open_timeout = 3
    res = req.request_head('/')
    #puts "code: #{res.code}"
    #puts "res: #{res.inspect}"
    if (res.code == "200" or res.code == "302" or res.code == "301" or res.code == "404" or res.code == "500")
      return true
    else
      return false
    end
  rescue Exception => ex
    puts ex.message
    return false # false if can't find the server
  end
  
  return false
end


#schemes = ['http', 'https']
ports = [80, 443, 3000, 8080]
  targets.each do |target|
#    schemes.each do |scheme|
      ports.each do |port|
        scheme = ''
        scheme = 'http' if (port == 80) 
        scheme = 'https' if (port == 443)
        scheme = 'http' if (port != 80 && port != 443)

        #puts "checking: #{scheme}://#{target}:#{port}"
        if File.exist?("../../public/ss/#{scheme}#{target}#{port}-ss.png")
          puts "Already screenshotted: #{scheme}://#{target}:#{port}, skipping"
          next
        end

        if (url_exist?("#{scheme}://#{target}:#{port}"))
          puts "exists, screenshotting: #{scheme}://#{target}:#{port}"

          begin
            screenshot = Gastly.screenshot("#{scheme}://#{target}:#{port}")
            screenshot.browser_width = 800
            screenshot.browser_height = 420
            screenshot.timeout = 1000
            screenshot.phantomjs_options = '--ignore-ssl-errors=true'
            image = screenshot.capture
            image.save("../../public/ss/#{scheme}#{target}#{port}-ss.png")

            File.open("web-applications-"+SecureRandom.uuid+".txt", 'w') { |file|
              file.write("#{scheme} #{target} #{port}\n")
            }
          rescue  => exception
            #puts "Error taking screenshot, possibly timeout."
            puts exception.message
            #exception.backtrace
          end
        else
          #puts "wasnt a site: #{scheme}://#{target}:#{port}"
        end
      end
    # end
  end
