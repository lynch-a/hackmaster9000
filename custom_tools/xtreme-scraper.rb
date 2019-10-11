#!/usr/bin/env ruby

require 'mechanize'

args = Hash[ ARGV.join(' ').scan(/--?([^=\s]+)(?:=(\S+))?/) ]

if (args.length < 2)
  puts "usage: xtreme-scraper -o=out_file.txt -p=num_pages_to_scrape"
  exit
end

if args['p']
  pages = args['p']
end

if args['o']
  output_file = args['o']
end

agent = Mechanize.new
File.open(output_file, 'w') { |file|
  (0..pages.to_i).each do |count|
    page = nil

    if count == 0
      page = agent.get('http://www.xtremetop100.com')
    else
      page = agent.get("http://www.xtremetop100.com/-#{50*count}")
    end

    page.links_with(:href => /^out\.php\?site*/).each do |link|
	   page = agent.get("http://www.xtremetop100.com/"+link.href)

	   out_url = page.body.match(/location\.href\=\"htt(p|ps)\:\/\/(.*?)(\/|\")/).captures[1]
     
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
}