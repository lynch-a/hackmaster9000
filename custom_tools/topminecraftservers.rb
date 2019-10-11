#!/usr/bin/env ruby

# scrape topminecraftservers website for targets

require 'mechanize'

args = Hash[ ARGV.join(' ').scan(/--?([^=\s]+)(?:=(\S+))?/) ]

if (args.length < 2)
  puts "usage: topminecraftservers -o=out_file.txt -p=num_pages_to_scrape"
  exit
end

if args['p']
  pages = args['p']
end

if args['o']
  output_file = args['o']
end

seen = []

agent = Mechanize.new
File.open(output_file, 'w') { |file|
  (0..pages.to_i).each do |count|
    page = nil

    if count == 0
      page = agent.get('https://topminecraftservers.org/')
    else
      page = agent.get("https://topminecraftservers.org/page/#{count}")
    end

    page.links_with(:href => /^\/server\//).each do |link|
      page = agent.get("https://topminecraftservers.org"+link.href)
      page.links_with(:href => /(.+)\?utm_source=/).each do |link2|
    	  out_url = link2.href.gsub("?utm_source=TopMinecraftServers.org", "").gsub("http://", "").gsub("https://", "").gsub("/", "")
        
        if (!seen.include? out_url)
          seen  << out_url

          ip = ""
          begin
            ip = IPSocket.getaddress(out_url)
            puts "#{out_url} #{ip}"
            file.write("#{out_url} #{ip}\n");
          rescue SocketError
            puts "couldn't find IP for #{out_url}"
          end
        end
      end
    end
  end
}