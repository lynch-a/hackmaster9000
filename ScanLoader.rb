require 'resque'
require 'nmap/parser'
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

      def self.load_dirsearch_scan(file)
        file_contents = File.read("hm9k-projects/"+@project.uuid+"/"+file)
        parsed = JSON.parse(file_contents)

        parsed.keys.each do |url|
          parsed_url = URI(url)
          dns_name = parsed_url.host
          scheme = parsed_url.scheme
          port = parsed_url.port

          db_web_application = ingest_web_application(dns_name, scheme, port)

          #flag = false # flag to see if anything changed in the dirsearch scan
          entries = []

          parsed[url].each do |entry|
            entries << {
              path: entry["path"],
              status: entry["status"],
              content_length: entry["content-length"]
            }
          end

          db_ds_scan = DirsearchScan.find_or_create_by(
            web_application_id: db_web_application.id,
          )
          db_ds_scan.save!

          entries.each do |entry|
            db_ds_result = DirsearchResult.find_or_initialize_by(
              dirsearch_scan_id: db_ds_scan.id,
              path: entry[:path],
              redirect: entry[:redirect],
              status: entry[:status],
              content_length: entry[:content_length]
            )
            if db_ds_result.new_record?
              checkTrigger(
                "dirsearch-result",
                [ # replacers
                  ["%url%", url+entry[:path]]
                ], [ # data matchers
                  ["path", entry[:path]],
                  ["status", entry[:status]],
                  ["redirect", entry[:redirect]],
                  ["content_length", entry[:content_length]]
                ]
              )

            end
            db_ds_result.save!
          end  # end each-entry

          db_host = Host.where(project_id: @project.id, ip: db_web_application.dns_record.record_value).first
          if (db_host)
            #send_host_refresh(db_host.id)
          end
          
          #send_web_application_refresh(db_web_application.id)
          
          if (db_web_application.dns_record.dns_name != "")
            #send_domain_refresh(db_web_application.dns_record.id)
          end
        end

      FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
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
      	    ingest_domain(name, "A", ip)
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

          db_dns_record = ingest_domain(line, "A", "")
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
          db_dns_record = ingest_domain(domain, "A", ip)

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
          db_dns_record = ingest_domain(domain, "A", "")
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

      # [["%ip%", "replaceWith"],["%domain%", "replace"]]
      # ["domain", the_domain_name]
      def checkTrigger(trigger_type, replacements, match_data)
        triggers = Trigger.where(project_id: @project.id, trigger_on: trigger_type, paused: false)

        # for each trigger found, make a job that fires immediately
        triggers.each do |trigger|
          #puts "checking trigger: #{trigger}"
          conditions = TriggerCondition.where(trigger_id: trigger.id)

          should_trigger = true # "did every condition match?" flag - false if any condition failed to match        

          flag = false # did this condition match?

          # assume pass on no conditions
          if (conditions.size == 0)
            flag = true
          end
          
          conditions.each do |condition|
            #puts "CONDITION CHECK STARTED vvvvv ---------------------"
            #puts "checking trigger condition: key: #{condition.match_key} val: #{condition.match_value}"
            match_data.each do |match|
              #puts "SANITY CHECK: #{condition.match_key} == #{match[0]}"
              if condition.match_key == match[0] # is this condition related to this trigger?
                if condition.match_type == "csv" 
                  condition.match_value.split(",").each do |csv_condition|
                    #puts "CHECKING CSV MATCH: #{match[1]} == #{csv_condition}"
                    if match[1] == csv_condition
                      flag = true
                    end
                  end
                elsif condition.match_type == "regex"
                  #puts "CHECKING REGEX: #{match[1]} === #{condition.match_value}"
                  if !!(match[1] =~ Regexp.new(condition.match_value)) # boolean check if regex matches
                    flag = true
                  end
                else
                  # more match types?
                end
              end
            end # end each match_data
            #puts "CONDITION CHECK ENDED ^^^^^^  ----------------------"
          end # end each-condition

          if (flag == false) # a condition did not match, we should not trigger the job
            #puts "A condition did not match, not triggering"
            should_trigger = false
          else
            #puts "all conditions matched, should be running job"
            should_trigger = true
          end

          if (should_trigger)
            #puts "Setting up job"
            # do shell replacements
            real_cmd = trigger.run_shell
            replacements.each do |replacer|
              real_cmd = real_cmd.gsub(replacer[0].to_s, replacer[1].to_s)
            end
            #puts "cmd to run: #{real_cmd}"

            # create the job
            db_job = Job.create!(
              user_id: trigger.user_id,
              project_id: @project.id,
              job_type: "TOOL",
              job_data: real_cmd,
              run_every: 0,
              last_run: 0,
              max_runtimes: 1,
              status: "queued",
              run_times: 0,
              run_in_background: trigger.run_in_background
            )

            # notify_project("danger", "Triggered: #{trigger.name}")
          end
        end # end each trigger
      end # end checkTrigger
      
      def ingest_web_application(dns_name, scheme, port)
        # check if the host name is instea an ip
        if !!(dns_name =~ /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/)
          # okay, it's an ip, ingest the host instead
          db_host = ingest_host(dns_name)

          # make a service because we know the port
          db_service = ingest_service(db_host.id, port, scheme, "", "", "")
          # make a dns record with no dns_name...
          db_dns_record = ingest_domain("", "A", dns_name) # dns name is really the ip
        else # it's really a dns record
          db_dns_record = ingest_domain(dns_name, "A", "")
        end

        db_web_application = WebApplication.find_or_initialize_by(
          project_id: @project.id,
          scheme: scheme,
          dns_record_id: db_dns_record.id,
          port: port
        )

        if db_web_application.new_record?
          db_web_application.update_attributes!(name: "New Application")

          # check for triggers
          #checkTrigger(
          #  "add-app",
          #  [["%domain%", dns_name], ["%scheme%", scheme], ["%port%", port]],
          #  [["port", port], ["domain", dns_name], "scheme", scheme],
          #)

          db_web_application.save

          # update the web app
          if (db_dns_record.dns_name != "")
            #send_web_application_refresh(db_web_application.id)
          end
          
          # update relevant domain
          if (db_dns_record.dns_name != "")
            #send_domain_refresh(db_dns_record.id)
          end

          # update any hosts that match the dns record
          Host.where(ip: db_dns_record.record_value).each do |db_host|
            #send_host_refresh(db_host.id)
          end
        end

        return db_web_application
      end

      def ingest_host(ip)
        puts "ingest host start"
        # check if the ip actually looks like an ip
        #puts "ingesting host"
        if !!!(ip =~ /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/)
          # it DOESNT look like an ip
          puts "ip looks like a domain instead, ingesting domain:"
          db_dns_record = ingest_domain(ip ,"A", "") # actually the ip here is a domain
          return nil
        end
        #puts "ingesting ip normally"

        db_host = Host.find_or_initialize_by(project_id: @project.id, ip: ip)

        if db_host.new_record?
          #puts "INGEST NEW HOST"

          # check for triggers
          checkTrigger(
            "add-host",
            [["%ip%", ip]],
            []
          )

          # potentially notify
        end

        db_host.save
        #send_host_refresh(db_host.id)

        return db_host
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

      def ingest_domain(dns_name, record_type, record_value)
         puts "domain ingest start"
	      # if ip is given, we check if we have a record_value
        if dns_name == ""
          #puts "ingesting ghost domain from ip: #{record_value}"


          db_dns_record = DnsRecord.find_or_initialize_by(
            project_id: @project.id,
            record_value: record_value,
            record_type: "A"
          )
          db_dns_record.save
          if (db_dns_record.dns_name.nil?)
            db_dns_record.update_attributes!(dns_name: "")
          end

          # .. make a host?
          # don't send a domain refresh because this is a ghost domain (only ip)
          # don't do any trigger because we don't know the actual domain name yet
        elsif record_value == "" # we were given a domain name with no ip
          #puts "ingesting domain w/o ip: #{dns_name}"

          db_dns_record = DnsRecord.find_or_initialize_by(
            project_id: @project.id,
            dns_name: dns_name,
            record_type: "A"
          )

          if (db_dns_record.new_record?)
            if (!db_dns_record.dns_name.nil?)
              checkTrigger(
                "add-domain",
                [["%domain%", dns_name]],
                [["domain", dns_name]] # check against all of the "domain" match keys in the conditions
              )
              db_dns_record.save

              #send_domain_refresh(db_dns_record.id)
            end
          end

          if (db_dns_record.record_value.nil?)
            db_dns_record.update_attributes(record_value: "")
          end

          db_dns_record.save
        else # neither are blank, so check if we have any blank records to combine:
          did_combine_flag = false # check if we combined any records
          #puts "checking if to combine new ingested domain: #{dns_name} - #{record_value}"

          # look for a dns record with a blank ip but known dns_name
          db_dns_record = DnsRecord.where(
            project_id: @project.id,
            dns_name: dns_name,
            record_type: "A"
          ).first

          if (db_dns_record) # we found a record by the given dns_name
            if (db_dns_record.record_value == "")
              db_dns_record.record_value = record_value
              db_dns_record.save
              did_combine_flag = true
            end
          end

          # now check for a dns record with a given ip but unknown dns_name
          db_dns_record = DnsRecord.where(
            project_id: @project.id,
            record_value: record_value,
            record_type: "A"
          ).first

          if (db_dns_record) # we found a record by the given ip
            if (db_dns_record.dns_name == "")
              db_dns_record.dns_name = dns_name
              db_dns_record.save
              did_combine_flag = true
            end
          end

          if did_combine_flag
            #puts "definitely combined 2 records, sending refresh and saving"
            #send_domain_refresh(db_dns_record.id)
          else # we couldn't combine with any previous domain record so we must make a new one from fresh start
            # but at least we are guaranteed to have dns_name and record_value
            #puts "making or finding brand spanking new dns record"

            new_dns_name_flag = true

            # check if the dns_name has been discovered before
            db_dns_record = DnsRecord.where(
              project_id: @project.id,
              dns_name: dns_name,
              record_type: "A"
            ).first

            if (db_dns_record) # we found a record by the given dns_name
              new_dns_name_flag = false
            end

            db_dns_record = DnsRecord.find_or_initialize_by(
              project_id: @project.id,
              dns_name: dns_name,
              record_type: "A",
              record_value: record_value
            )

            if (db_dns_record.new_record? and new_dns_name_flag)
              checkTrigger(
                "add-domain",
                [["%domain%", dns_name], "%ip%", record_value],
                [["domain", dns_name]] # check against all of the "domain" match keys in the conditions
              )
              db_dns_record.save
              
              #send_domain_refresh(db_dns_record.id)
            end
          end
        end

        # while we import a domain, if this domain points to a hidden IP, we want to hide the domain too
        if (db_dns_record.record_value != "")
          if (Host.where(project_id: @project.id, ip: db_dns_record.record_value, hidden: true).count > 0)
            db_dns_record.hidden = true
            db_dns_record.save
          end
        end
       puts "ingest_domain end"
        return db_dns_record
      end

      def ingest_nmap_service_script(service_id, dns_records, script_name, script_output)
        db_service_script = ServiceScript.find_or_initialize_by(
          service_id: service_id,
          script_id: script_name,
          script_output: script_output
        )

        db_service = Service.where(id: service_id).first

        if db_service_script.new_record?
          #puts "NEW SERVICE SCRIPT"
          dns_records.each do |dns_record|
            checkTrigger(
              "script",
              [
                ["%ip%", db_service.host.ip],
                ["%port%", db_service.port_number],
                ["%domain%", dns_record.dns_name ]
              ], [
                ["script-name", script_name],
                ["script-output", script_output],
                ["script-port", db_service.port_number.to_s]
              ]
            )
          end
          if dns_records.count == 0
            # do a trigger without %domain% - we got a new script,
            # but it doesn't have a domain yet, and that's ok
            checkTrigger(
              "script",
              [
                ["%ip%", db_service.host.ip],
                ["%port%", db_service.port_number]
              ], [
                ["script-name", script_name],
                ["script-output", script_output],
                ["script-port", db_service.port_number.to_s]
              ]
            )
          end
        end

        db_service_script.save
      end

      def ingest_service(host_id, port, name, product, version, confidence)
        db_service = Service.find_or_initialize_by(
          host_id: host_id,
          port_number: port,
          project_id: @project.id
        )

        if db_service.new_record?
          checkTrigger(
            "add-service",
            [
              ["%ip%", Host.where(id: host_id).first.ip],
              ["%port%", port]
            ], [
              ["port", port]
            ]
          )
        end

        db_service.update_attributes!(
          service_name: name,
          service_product: product,
          service_version: version,
          service_confidence: confidence
        )

        db_service.save!

        return db_service
      end

      def ingest_nmap_host_script(host_id, script_name, script_output)
        db_host_script = HostScript.find_or_initialize_by(
          host_id: host_id,
          script_id: script_name,
          script_output: script_output
        )
        
        db_host = Host.where(project_id: @project.id, id: host_id).first

        if (db_host_script.new_record?)
          checkTrigger(
            "script",
            [["%ip%", db_host.ip]],
            [["script-name", script_name], ["script-output", script_output]]
          )
        end
        db_host_script.save
      end

      def self.load_nmap_scan(file)
        file_contents = File.read("hm9k-projects/"+@project.uuid+"/"+file)

        parser = Nmap::Parser.parsestring(file_contents)

        parser.hosts("up") do |nmap_host|
          db_host = ingest_host(nmap_host.ipv4_addr)

          nmap_host.scripts do |nmap_script|
            puts "script: #{nmap_script}"
            ingest_nmap_host_script(db_host.id, nmap_script.id, nmap_script.output)
          end
          
          db_dns_records = []
          nmap_host.hostnames().each do |nmap_hostname|
           db_dns_record = ingest_domain(nmap_hostname, "A", nmap_host.ipv4_addr)
           db_dns_records << db_dns_record

            if (db_dns_record.dns_name != "")
              #send_domain_refresh(db_dns_record.id)
            end
          end

          [:tcp, :udp].each do |type|
            nmap_host.getports(type, "open") do |nmap_port|
              nmap_service = nmap_port.service

              db_service = ingest_service(db_host.id, nmap_port.num, nmap_service.name, nmap_service.product, nmap_service.version, nmap_service.confidence)

              nmap_port.scripts do |nmap_script|
                ingest_nmap_service_script(db_service.id, db_dns_records, nmap_script.id, nmap_script.output)
              end
            end
          end

          #send_host_refresh(db_host.id)
        end

        FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)

        "true" # just assume it worked
      end

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

          db_dns_record = ingest_domain(dns_name, "A", ip_addr)
          db_host = ingest_host(ip_addr)

          #send_host_refresh(db_host.id)
          #send_domain_refresh(db_dns_record.id)
        end

        FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
        return "true"
      end

      def is_being_written_to(file_path)
        fuller_path = "hm9k-projects/#{@project.uuid}/#{file_path}"
        return `lsof #{fuller_path} | grep COMMAND`.length > 0
      end

      # filter like: "nmap-*.xml" to search project home directory
      # returns: array of basename'd file paths
      def find_project_files_basename(filter)
        #puts "found files: #{Dir["hm9k-projects/#{@project.uuid}/"+filter].map{|filename| File.basename(filename)}}"
        return Dir["hm9k-projects/#{@project.uuid}/"+filter].map{|filename| File.basename(filename)}
      end
      ## note: if an attacker can control the scheduler and therefore control scanloader jobs,
      ## it is possible to create a malicious job that affects the Dir[] command here
      ## which potentially scans arbitrary paths. does it matter? ¯\_(ツ)_/¯
      ## 
      def load_scans(project)
        puts "starting scanloader for project: #{project.uuid}"

        scan_these = {
          "nmap": {
            "parser_function": :load_nmap_scan, 
            "file_list": find_project_files_basename("nmap-*.xml")
          },
          "dirsearch": {
            "parser_function": :load_dirsearch_scan,
            "file_list": find_project_files_basename("dirsearch-*.json")
          },
          "dnscan": {
            "parser_function": :load_dnscan,
            "file_list": find_project_files_basename("dnscan-*.txt")
          },
          "crtsh": {
            "parser_function": :load_crtsh_scan,
            "file_list": find_project_files_basename("crtsh-*.json")
          },
          "raw domain": {
            "parser_function": :load_raw_domain_ip,
            "file_list": find_project_files_basename("raw-domain-ip-*.txt")
          },
          "raw web application": {
            "parser_function": :load_raw_web_applications,
            "file_list": find_project_files_basename("web-applications-*.txt")
          },
          "raw web request": {
            "parser_function": :load_raw_web_request,
            "file_list": find_project_files_basename("web-request-*.txt")
          },
          "bounty target domains": {
            "parser_function": :load_raw_domain,
            "file_list": find_project_files_basename("btd-*.txt")
          },
          "pwnvnc": {
            "parser_function": :load_pwnvnc,
            "file_list": find_project_files_basename("pwnvnc-*.txt")
          },
          "git-rip": {
            "parser_function": :load_gitrip,
            "file_list": find_project_files_basename("gitrip-*.txt")
          },
	         "zdns": {
            "parser_function": :load_zdns,
	           "file_list": find_project_files_basename("zdns-*.txt")
          },
	         "zmap": {
            "parser_function": :load_zmap,
	           "file_list": find_project_files_basename("zmap-*.csv")
	         }
        }

        loaded_scans = 0
        send_refreshes = false
        scan_these.each do |scan_name, scan_data|
          #puts "running parser: #{scan_name} - #{scan_data}"
          scan_data[:file_list].each do |file| # each file found for tool
            if (!is_being_written_to(file))
              begin
                #notify_project("success", "Parsing #{file}")
                send(scan_data[:parser_function], file)
                send_refreshes = true
                loaded_scans = loaded_scans + 1
                if (loaded_scans == 1)
                  notify_project("success", "Loaded #{scan_name} file: #{file}")
                end
              rescue => e
                notify_project("danger", "There was an error parsing #{scan_name} data: #{file} - #{e.message}")
                puts e.backtrace
              end
            end
          end # end each scan file

          if (loaded_scans > 0)
            # create a notification group of everything that changed in this scan load
          end
          if (loaded_scans > 1)
            notify_project("success", "... Also loaded #{loaded_scans-1} other #{scan_name} scans.")
          end
          loaded_scans = 0
        end # end each scan type
        
        puts "Done parsing scans!"

        # a scan was parsed, so update all the tables
        if (send_refreshes)
          send_host_refresh(-1)
          send_domain_refresh(-1)
          send_web_application_refresh(-1)
        end
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
            scanloader_key: "12345" #todo
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
