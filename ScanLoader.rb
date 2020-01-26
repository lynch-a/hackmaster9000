require 'resque'
require 'fileutils'
require 'csvreader'
require 'faye/websocket'
require 'eventmachine'
require 'json'
require 'filelock'
require 'cgi'
require 'webrick'
require 'addressable/uri'

begin
  lockfile = "hm9k-projects/.scanlock"

  Filelock lockfile, wait: 2, timeout: 0 do
    require './db.rb'

    puts "running scanloader... project: #{ARGV[0]}"
    @project = Project.where(uuid: ARGV[0]).first
    puts "project: #{@project.uuid}"
    
    ## surprise, it's just a websocket client
    EM.run {

      @ws = Faye::WebSocket::Client.new('ws://127.0.0.1:8082') ## the api server!!!

=begin
      def update_host_feed(db_host, header, text, refresh)
        # create a host_detail (feed item)
        # Todo: move this to a convenience method
        db_host_detail = HostDetail.create!(
          host_id: db_host.id,
          header: header,
          render_type: "pre",
          value: text
        )
        db_host_detail.save # save the feed item
        db_host.host_details << db_host_detail # update the host feed with the feed item
        db_host.save 

        send_host_refresh(db_host.id) if refresh

        return db_host_detail
      end
=end
      def update_host_feed(db_host, header, text, refresh)
        # create a host_detail (feed item)
        # Todo: move this to a convenience method
        db_feed_item = FeedItem.create!(
          data_id: db_host.id,
          data_type: "host",
          header: header,
          value: text
        )
        #db_host_feed.host_details << db_host_detail # update the host feed with the feed item
        db_feed_item.save 

        #send_host_refresh(db_host.id) if refresh

        return db_feed_item
      end

      def update_domain_feed(db_dns_record, header, text, refresh)
        # create a host_detail (feed item)
        # Todo: move this to a convenience method
        db_feed_item = FeedItem.create!(
          data_id: db_dns_record.id,
          data_type: "domain",
          header: header,
          value: text
        )
        #db_host_feed.host_details << db_host_detail # update the host feed with the feed item
        db_feed_item.save 

        #send_host_refresh(db_host.id) if refresh

        return db_feed_item
      end

      def update_web_application_feed(db_web_application, header, text, refresh)
        # create a host_detail (feed item)
        # Todo: move this to a convenience method
        db_feed_item = FeedItem.create!(
          data_id: db_host.id,
          data_type: "host",
          header: header,
          value: text
        )
        #db_host_feed.host_details << db_host_detail # update the host feed with the feed item
        db_feed_item.save 

        #send_host_refresh(db_host.id) if refresh

        return db_feed_item
      end

     
      require 'csv'
      def load_zmap(file)
      	CSV.foreach("hm9k-projects/"+@project.uuid+"/"+file, headers: true) do |row|
                ip = row['saddr']
      	  port = row['sport']

      	  db_host = ingest_host(ip)
      	  ingest_service(db_host.id, port, "zmap", "", "", "")
              end
            FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
            end

            def load_zdns(file)
              file_contents = File.read("hm9k-projects/"+@project.uuid+"/"+file)
              
      	file_contents.each_line do |line|
                next if (line.length <  4) # garbo
                next if line.include? "NO_ANSWER"
      	  
      	  parsed = JSON.parse(line.strip!)
                name = parsed["name"]
      	  status = parsed["status"]
      	  if status == "NOERROR"
                  ip = parsed["data"]["ipv4_addresses"][0]
      	    ingest_dns_record(name, "A", ip)
      	    ingest_host(ip) # maybe
      	  end
              end
      	File.delete("hm9k-projects/"+@project.uuid+"/"+file)
      end

      def load_raw_web_applications(file)
        file_contents = File.read("hm9k-projects/"+@project.uuid+"/"+file)

        file_contents.each_line do |line|
          line = line.split(" ")
          next if (line.length !=  3) # remove lines with no ip

          scheme = line[0]
          domain = line[1]
          port = line[2]

          db_web_application = ingest_web_application(domain, scheme, port)

          #send_web_application_refresh(db_web_application.id)
        end
        FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
      end

      def load_raw_web_request(file)
        file_contents = File.read("hm9k-projects/"+@project.uuid+"/"+file)

        info_line = Addressable::URI.parse(file_contents.lines[0].strip)

        scheme = info_line.scheme
        domain = info_line.host
        port = info_line.port

        db_web_application = ingest_web_application(domain, scheme, port)

        raw_http_request = file_contents.lines[1..-1].join("")

        if db_web_application
          request = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP)
          request.parse(StringIO.new(raw_http_request))

          # create the page
          # todo: check if page exists
          db_page = Page.find_or_create_by!(
            web_application_id: db_web_application.id,
            path: request.path,
          )
          puts "made page!"

          if request.request_method == "GET"
            params = WEBrick::HTTPUtils.parse_query(request.query_string)
            params.each {|key, value|
              Input.find_or_create_by!(page_id: db_page.id, name: key, value: value, http_method: "GET")
            } 
            puts "made GET params!"
          elsif request.request_method == "POST"
            params = WEBrick::HTTPUtils.parse_query(request.body)
            params.each {|key, value|
              Input.find_or_create_by!(page_id: db_page.id, name: key, value: value, http_method: "POST")
            } 
            puts "made POST params!"
          end

          puts request.inspect

          # associate header data with it, too
          request.each {|header, value|
            h = Header.find_or_create_by!(page_id: db_page.id, name: header, value: value)
            puts "#{header} - #{value}"
            h.save!
          }
        else
          puts "Web app not found!!!!"
        end 

        FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
      end

      def load_pwnvnc(file)
        # First, load the full path to the scanfile. ScanLoader.rb executes
        # from the hackmaster9000/ folder itself.
        # The scanloader knows what project it's loading, so this will load 
        # the extended path to the exact scan file.
        file_contents = File.read("hm9k-projects/#{@project.uuid}/#{file}")

        # An output file for pwnvnc is very simple. iff the given IP and port to the tool are found to have an unauth VNC server running, an output file is written.
        # An output file looks like this:

        # name: pwnvnc-anything.txt
        # contents:
        #------------------
        # 127.0.0.1 5900  |
        # \EOF            |
        #------------------

        # So we have to ingest an IP and a port.
        # An IP is best associated with a "host", so we will use the ingest_host(ip) function
        # A port is best associated as a "service", so we will use the ingest_service(...) function

        # Go ahead and read each line of the pwnVNC output file individually
        # (This is useless because the output file only has one line, but
        # I have plans to extend the VNC script to include multiple hosts)
        file_contents.each_line do |line|
          next if (line.length <  2) # remove garbage lines
          line.strip! # remove any extra whitespaces around the current parsed line
          split = line.split(" ") # split the line by the single whitespace we know is between the IP and port

          ip = split[0] # variable to hold the parsed ip as a string
          port = split[1] # variable to hold the parsed port as a string

          # Now that we have parsed the output file line, we have the information we need to
          # create the database items.
          # ingest_*() methods will do all the heavy lifting of committing real database
          # updates (scan data).
           
          # The ingest_host() function takes one argument, the string IP address
          # and returns an ActiveRecord database record of which:
          # 1) If the ip address already exists in the database, nothing is 
          #    triggered and the existing row is returned.
          # 2) If the ip address has never seen before, a new one is created, triggers
          #    are launched, and the new row is returned.
          # 3) If the given ip address does not match an IP address regex,
          #    it is assumed to be a domain, and is ingested as a dns record instead and returns nil (TODO)

          db_host = ingest_host(ip)

          #(TODO): It's hard to handle dealing with potentially returning domains here, so we ignore them
          if (db_host) # todo: if ingest_host returns nil, it means it was given a domain. it created the domain instead and won't return the id so we can't update a domain in the ui
            # If we are in this if statement, it means the db_host was created (or already existed)
            # and therefore the IP address from the output file has been parsed.
            # But we still must ingest a service.
            # Ingesting a service will first check if a service exists.
            # If the service exists:
            #  1) Update the service with the information provided in the arguments
            #  2) Return the service (no triggers)
            # If the service is new:
            # 1) Create the service with the specified parameters,
            # 2) Run any triggers
            # 3) Return the service

            db_service = ingest_service(db_host.id, port, "Unauthenticated VNC - pwnVNC", "", "", "")

            # We also need to update the host feed  with a summarized version of what happened

            # we should also create a feed update here
            feed_str = "pwnVNC discovered VNC service on port: #{db_service.port_number} has unauth access. SS: /ss/vnc-#{db_host.ip}-#{db_service.port_number}.jpg"
            update_host_feed(db_host, "pwnVNC", feed_str, true)

            # TODO: figure out how to update the domain if it was added this way?
          end
        end
        FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
      end

      def load_raw_domain(file)
        file_contents = File.read("hm9k-projects/"+@project.uuid+"/"+file)

        file_contents.each_line do |line|
          next if (line.length <  2) # remove garbage
          line.strip!

          db_dns_record = ingest_dns_record(line, "A", "")
          #send_domain_refresh(db_dns_record.id)
        end
        FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
      end

      def self.load_raw_domain_ip(file)
        file_contents = File.read("hm9k-projects/"+@project.uuid+"/"+file)

        file_contents.each_line do |line|
          line = line.split(" ")
          next if (line.length !=  2) # remove lines with no ip

          domain = line[0]
          ip = line[1]

          db_host = ingest_host(ip)
          db_dns_record = ingest_dns_record(domain, "A", ip)

          #send_host_refresh(db_host.id)
          #send_domain_refresh(db_dns_record.id)
        end
        FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
      end

      def self.load_crtsh_scan(file)
        file_contents = File.read("hm9k-projects/"+@project.uuid+"/"+file)

        # we want to prevent duplicates from being saved here
        seen_domains = []

        JSON.parse(file_contents).each do |item|
          # skip wildcard certs, we just want subdomains from it
          next if item["name_value"].include? "?" or item["name_value"].include? "*"
          # skip records we've already seen
          next if seen_domains.include? item["name_value"]
          seen_domains << item["name_value"].downcase
        end

        seen_domains.each do |domain|
          db_dns_record = ingest_dns_record(domain, "A", "")
          #send_domain_refresh(db_dns_record.id)
        end

      FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
      end

      def notify_project(type, message)
        type = CGI.escapeHTML(type)
        message = CGI.escapeHTML(message)
        
        notification_data = {
          message: message,
          type: type
        }
        @ws.send('{"event": "notify", "data": '+ notification_data.to_json + "}")
      end

      def send_web_application_refresh(web_application_id)
        update_web_application_data = {
          id: web_application_id
        }
        @ws.send('{"event": "update-application", "data": '+ update_web_application_data.to_json + "}")
        #notify_project("info", "Application #{WebApplication.where(id: web_application_id).first.name} was updated.")
      end

      def send_domain_refresh(domain_id)
        update_domain_data = {
          id: domain_id
        }
        @ws.send('{"event": "update-domain", "data": '+ update_domain_data.to_json + "}")
        #notify_project("info", "Domain #{DnsRecord.where(id: domain_id).first.dns_name} was updated.")
      end

      def send_host_refresh(host_id)
        update_host_data = {
          id: host_id
        }
        @ws.send('{"event": "update-host", "data": '+ update_host_data.to_json + "}")
        #notify_project("info", "Host #{Host.where(id: host_id).first.ip} was updated.")
      end

      require './ingesters/web_application.rb'
      require './ingesters/host.rb'
      require './ingesters/dns_record.rb'
      require './ingesters/nmap_service_script.rb'
      require './ingesters/nmap_host_script.rb'
      require './ingesters/service.rb'



      def self.load_dnscan(file)
        file_contents = File.read("hm9k-projects/"+@project.uuid+"/"+file)

        flag = false # are we parsing A records yet
        domains_created = 0
        file_contents.each_line do |line|
          if !flag
            if !line.include? "for A records"
              next
            else
              flag = true
              next
            end
          end

          # parsing A records below

          # check if there's a [, stop parsing A records if there is
          if line[0] == "["
            return
          end

          next if line.blank?

          #puts "PARSING DNSCAN LINE: #{line}"
          data = line.split(" - ")
          ip_addr = data[0]
          dns_name = data[1].strip

          db_dns_record = ingest_dns_record(dns_name, "A", ip_addr)
          db_host = ingest_host(ip_addr)

          #send_host_refresh(db_host.id)
          #send_domain_refresh(db_dns_record.id)
        end

        FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
        return "true"
      end

      def is_being_written_to(file_path)
        fuller_path = "hm9k-projects/#{@project.uuid}/#{File.basename(file_path)}"
        return `lsof #{fuller_path} | grep COMMAND`.length > 0
      end

      def find_plugin_files(file_filter)
        #puts "found files: #{Dir["hm9k-projects/#{@project.uuid}/"+filter].map{|filename| File.basename(filename)}}"
        return Dir["hm9k-projects/#{@project.uuid}/"+file_filter].map{|filename| filename}
      end
      ## note: if an attacker can control the scheduler and therefore control scanloader jobs,
      ## it is possible to create a malicious job that affects the Dir[] command here
      ## which potentially scans arbitrary paths. does it matter? ¯\_(ツ)_/¯
      ##

      def load_scans(project)
        puts "starting scanloader for project: #{project.uuid}"

        require './plugins/Hm9kPlugin.rb'

        Dir["./plugins/*/plugin.rb"].each { |f| require f }
        Hm9kPlugin.register_plugins

        Hm9kPlugin.plugins.each do |plugin|
          puts "Running plugin: #{plugin.name}"
          files_to_parse = find_plugin_files(plugin.file_filter)

          parsed = 0
          files_to_parse.each do |file|
            next if is_being_written_to(file)

            begin
              plugin.parse(@project.id, file)
              parsed = parsed + 1
              FileUtils.move("hm9k-projects/"+@project.uuid+"/"+File.basename(file), "hm9k-projects/"+@project.uuid+"/scans/parsed/"+File.basename(file))
            rescue => e
              notify_project("danger", "#{plugin.name} failed to parse: #{File.basename(file)} - #{e.message}")
              puts e.backtrace
            end

            notify_project("success", "#{plugin.name} parsed file: #{File.basename(file)}")
          end

          if parsed > 0
            send_host_refresh(-1)
            send_domain_refresh(-1)
            send_web_application_refresh(-1)
          end
          # remove the file here maybe?
        end

        puts "Done parsing scans!"
      end

      @ws.on :open do |event|
      end

      @ws.on :message do |event|
        puts "RECV: " + event.data

        msg = JSON.parse(event.data)

        puts "event: #{msg["event"]}"

        if (msg["event"].eql? "authrequest")
          puts "Authing... uid: #{@project.uuid}"

          auth_event_data = {
            uuid: @project.uuid,
            scanloader_key: File.read("hackjob_secret.txt") #todo
          }
          #todo: easy refactor for sending events: make a method that builds these requests.
          puts 'SEND: {"event": "auth", "data": '+auth_event_data.to_json + "}"

          @ws.send('{"event": "auth", "data": '+auth_event_data.to_json + "}")

          load_scans(@project) # we'll auth correctly  so just go ahead and start working

          
          #EventMachine::stop_event_loop
          EM.add_timer(2) do 
            EM.stop 
            exit 
          end 
        else
          puts "was not an auth request!"
        end
      end

      @ws.on :close do |event|
        p [:close, event.code, event.reason]
        @ws = nil
      end
    }
  end
rescue SystemExit
  puts "exiting..."
end
