require 'json'
require 'pty'
require 'io/console'
require 'em-websocket'
require 'webrick'
require 'stringio'

require './db.rb'
require './config.rb'

EM.run do
  puts "API Server Started"


  # we keep track of the websocket connections by project ID as hash key
  # so that we can send events related to only one project

  # connected_users = {someproject: [user1, user2, user3], otherproject: ...}
  @connected_users = {}

  EM::WebSocket.run(host: $api_server_bind_address, port: $api_server_bind_port) do |ws|
    @channel = EM::Channel.new

    authenticated = false
    user = nil
    project = nil
    scanloader = false # this will be true if the scanloader has authed to the api
    # the scanloader can trigger special events to propogate out host data

    ws.onopen do |handshake|
      puts "Connection! requesting auth..."

      auth_event_data = {
        #auth: ""
      }

      # send auth first
      ws.send('{"event": "authrequest", "data": '+auth_event_data.to_json + "}")
      puts 'SEND: {"event": "authrequest", "data": '+auth_event_data.to_json + "}"
    end

    ws.onclose do
      # get active terminals in this WS and unhook them all

      puts "a connection has closed!! removing it from connected_users"
    end

    ws.onmessage do |msg|
      msg = JSON.parse(msg)
      puts "RECV: #{msg}"

      if (!authenticated) # wait for auth message to verify connection and setup user vars
        if msg["event"] == "auth"
          api_token = msg["data"]["api_token"];
          scanloader_key = msg["data"]["scanloader_key"]

          # regular user auth detected
          if (api_token)
            user = User.where(session_key: api_token).first

            if (!user)
              ws.send "Authentication required."
              ws.close(1000)
              #return
            else

              project = Project.where(uuid: msg["data"]["uuid"]).first

              # todo: check if user has access to project
              #if (user.projects.)
              # kill WS if user doesn't
              
              new_user_hash = {}
              new_user_hash[project.id] = [ws]
              
              @connected_users.merge!(new_user_hash) do |key, oldval, newval|
                oldval | newval
              end
              
              authenticated = true

              puts "User authed! project: #{project.uuid}"
            end
          elsif (scanloader_key) # fancy scanloader auth detected
            puts "authing a scanloader.."
            if (scanloader_key == "12345") # todo: great auth
                authenticated = true
                scanloader = true
                project = Project.where(uuid: msg["data"]["uuid"]).first
                puts "Scanloader authed! project: #{project.uuid}"
            else
              puts "Failed scanloader login..."
              ws.send "Authentication required."
              ws.close(1000)
            end
          end
        end
      else # go ahead and parse regular authed json events, we are authenticated
        puts "parsing regular authed events..."

        if (msg["event"] == "hide-web-application")
          id = msg["data"]["id"]
          
          # only works if the user authenticated to this project and everything exists
          db_web_application = WebApplication.where(id: id, project_id: project.id).first
          db_web_application.hidden = true
          db_web_application.save

          # tell everyone else about the new risk!
          hide_web_application_event_data = {
            id: db_web_application.id,
          }

          @connected_users[project.id].each do |user|
            user.send('{"event": "hide-web-application", "data": '+ hide_web_application_event_data.to_json + "}")
          end
          notification_event_data = {
            message: "Web application hidden: #{db_web_application.dns_record.dns_name}",
            type: "info"
          }

          if (@connected_users.key? project.id)
            @connected_users[project.id].each do |user|
              user.send('{"event": "notification", "data": '+ notification_event_data.to_json + "}");
            end
          end
        end

        if (msg["event"] == "delete-job")
          puts "adding a job!"
          job_id = msg["data"]["job_id"]

          db_job = Job.where(
            user_id: user.id,
            project_id: project.id,
            id: job_id,
            job_type: "TOOL"
          ).first

          if (db_job)
            db_job.destroy

            # tell everyone else about the new job!
            #puts "connected users: #{@connected_users}"
            puts "deleted job!"
            add_job_event_data = {job_id: db_job.id, project_id: project.id}
            @connected_users[project.id].each do |user|
              user.send('{"event": "refresh-jobs", "data": '+add_job_event_data.to_json + "}")
            end

            notification_event_data = {
              message: "Job removed: #{db_job.job_data}",
              type: "info"
            }

            if (@connected_users.key? project.id)
              @connected_users[project.id].each do |user|
                user.send('{"event": "notification", "data": '+ notification_event_data.to_json + "}");
              end
            end
          end
        end

        if (msg["event"] == "hide-host")
          id = msg["data"]["id"]
          
          # only works if the user authenticated to this project and everything exists
          db_host = Host.where(id: id, project_id: project.id).first
          db_host.hidden = true
          db_host.save

          # also hide all DNS records associated with this host
          dns_records = DnsRecord.where(record_type: ["A"], record_value: db_host.ip).where.not(dns_name: "")
          dns_records.each do |dns_record|
            dns_record.hidden = true
            dns_record.save
          end

          refresh_event_data = {
          }

          @connected_users[project.id].each do |user|
            user.send('{"event": "refresh-tables", "data": '+ refresh_event_data.to_json + "}")
          end
          
          notification_event_data = {
            message: "Host hidden: #{db_host.ip}",
            type: "info"
          }

          if (@connected_users.key? project.id)
            @connected_users[project.id].each do |user|
              user.send('{"event": "notification", "data": '+ notification_event_data.to_json + "}");
            end
          end
        end


        if (msg["event"] == "set-domain-risk")
          domain_id = msg["data"]["id"]
          domain_risk = msg["data"]["risk"]
          
          # only works if the user authenticated to this project and everything exists
          domain = DnsRecord.where(id: domain_id).where(project_id: project.id).first
          domain.risk = domain_risk
          domain.save

          # tell everyone else about the new risk!
          set_domain_risk_event_data = {
            id: domain.id,
            risk: domain.risk
          }

          @connected_users[project.id].each do |user|
            user.send('{"event": "set-domain-risk", "data": '+set_domain_risk_event_data.to_json + "}")
          end
          notification_event_data = {
            message: "Domain risk updated: #{domain.dns_name} - #{domain.risk}",
            type: "info"
          }

          if (@connected_users.key? project.id)
            @connected_users[project.id].each do |user|
              user.send('{"event": "notification", "data": '+ notification_event_data.to_json + "}");
            end
          end
        end

        if (msg["event"] == "set-host-risk")
          host_id = msg["data"]["id"]
          host_risk = msg["data"]["risk"]
          
          # only works if the user authenticated to this project and everything exists
          host = Host.where(id: host_id).where(project_id: project.id).first
          host.risk = host_risk
          host.save

          # tell everyone else about the new risk!
          set_host_risk_event_data = {
            id: host.id,
            risk: host.risk
          }

          @connected_users[project.id].each do |user|
            user.send('{"event": "set-host-risk", "data": '+set_host_risk_event_data.to_json + "}")
          end
          notification_event_data = {
            message: "Host risk updated: #{host.ip} - #{host.risk}",
            type: "info"
          }

          if (@connected_users.key? project.id)
            @connected_users[project.id].each do |user|
              user.send('{"event": "notification", "data": '+ notification_event_data.to_json + "}");
            end
          end
        end

        puts "parsing regular authed events..."
        if (msg["event"] == "set-web-application-risk")
          web_application_id = msg["data"]["id"]
          web_application_risk = msg["data"]["risk"]
          
          db_web_application = WebApplication.where(
            project_id: project.id,
            id: web_application_id
          ).first
          db_web_application.risk = web_application_risk
          db_web_application.save

          # tell everyone else about the new risk!
          set_web_application_risk_event_data = {
            id: db_web_application.id,
            risk: web_application_risk
          }

          @connected_users[project.id].each do |user|
            user.send('{"event": "set-web-application-risk", "data": '+set_web_application_risk_event_data.to_json + "}")
          end
          notification_event_data = {
            message: "Web Application risk updated: #{db_web_application.dns_record.dns_name} - #{db_web_application.risk}",
            type: "info"
          }

          if (@connected_users.key? project.id)
            @connected_users[project.id].each do |user|
              user.send('{"event": "notification", "data": '+ notification_event_data.to_json + "}");
            end
          end
        end

        if (msg["event"] == "new-domain-comment")
          domain_id = msg["data"]["id"]
          domain_comment = msg["data"]["comment"]
          
          # only works if the user authenticated to this project and everything exists
          db_dns_record = DnsRecord.where(id: domain_id).where(project_id: project.id).first
          db_dns_record.update_attributes(note: domain_comment)
          db_dns_record.save

          
          # tell everyone else about the comment; prompt reload of domain
          new_domain_comment_event_data = {
            id: db_dns_record.id,
            dns_name: db_dns_record.dns_name
          }


          @connected_users[project.id].each do |user|
            user.send('{"event": "new-domain-comment", "data": '+ new_domain_comment_event_data.to_json + "}")
          end
        end

        if (msg["event"] == "web-application-comment")
          web_application_id = msg["data"]["id"]
          web_application_comment = msg["data"]["comment"]
          
          # only works if the user authenticated to this project and everything exists
          db_web_application = WebApplication.where(id: web_application_id).where(project_id: project.id).first
          db_web_application.description = web_application_comment
          db_web_application.save
          
          # tell everyone else about the comment; prompt reload of domain
          web_application_comment_event_data = {
            id: db_web_application.id,
            web_application_comment: db_web_application.description
          }

          @connected_users[project.id].each do |user|
            user.send('{"event": "web-application-comment", "data": '+ web_application_comment_event_data.to_json + "}")
          end
        end

        if (msg["event"] == "new-host-comment")
          host_id = msg["data"]["id"]
          host_comment = msg["data"]["comment"]
          
          # only works if the user authenticated to this project and everything exists
          db_host = Host.where(id: host_id).where(project_id: project.id).first
          db_host.update_attributes(note: host_comment)
          db_host.save

          # tell everyone else about the comment; prompt reload of domain
          new_host_comment_event_data = {
            id: db_host.id,
            ip: db_host.ip
          }

          @connected_users[project.id].each do |user|
            user.send('{"event": "new-host-comment", "data": '+ new_host_comment_event_data.to_json + "}")
          end
        end

        if (msg["event"] == "add-job")
          puts "adding a job!"
          job_type = msg["data"]["job_type"]
          job_data = msg["data"]["job_data"]
          job_run_every = msg["data"]["job_run_every"]
          #job_last_run = msg["data"]["job_last_run"]
          job_max_runtimes = msg["data"]["job_max_runtimes"]

          job_run_in_background = msg["data"]["job_run_in_background"]

          #todo (HIGH PRIORITY): if you provide null values to this, it crashes the scheduler
          
          # only works if the user authenticated to this project and everything exists
          db_job = Job.create!(
            user_id: user.id,
            project_id: project.id,
            job_type: job_type,
            job_data: job_data,
            run_every: (job_run_every.to_i*60),
            last_run: 0,
            max_runtimes: job_max_runtimes.to_i,
            status: "queued",
            run_times: 0,
            paused: false,
            run_in_background: job_run_in_background
          )

          # tell everyone else about the new job!
          #puts "connected users: #{@connected_users}"
          puts "made job!"
          add_job_event_data = {job_id: db_job.id, project_id: project.id}
          @connected_users[project.id].each do |user|
            user.send('{"event": "refresh-jobs", "data": '+add_job_event_data.to_json + "}")
          end

          notification_event_data = {
            message: "Job queued",
            type: "info"
          }

          if (@connected_users.key? project.id)
            @connected_users[project.id].each do |user|
              user.send('{"event": "notification", "data": '+ notification_event_data.to_json + "}");
            end
          end

        end

        if (msg["event"] == "parse-http-request")
          puts "Parsing http request!"
          app_id = msg["data"]["app_id"]
          raw_http_request = msg["data"]["raw_http_request"]
          # parsing user data... just ignore errors so it DOESNT CRASH THE WHOLE API KEK
          begin
            # find relevant application in db
            db_web_application = WebApplication.where(project_id: project.id, id: app_id).first

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

              # associate header data with it, too
              request.each {|header, value|
                Header.find_or_create_by!(page_id: db_page.id, name: header, value: value)
                puts "#{header} - #{value}"
              }

              new_page_event_data = {project_id: project.id, web_application_id: db_web_application.id, page_id: db_page.id}
              @connected_users[project.id].each do |user|
                user.send('{"event": "new-page", "data": '+new_page_event_data.to_json + "}")
              end
            else
              puts "could not find web application!"
            end
          rescue => exception
            puts exception.backtrace
            raise
          end
        end

        if (msg["event"] == "add-scan-config")
          puts "adding a scan config!"
          scan_name = msg["data"]["name"]
          scan_tool = msg["data"]["tool_name"]
          scan_options = msg["data"]["options"]
          
          # only works if the user authenticated to this project and everything exists
          db_tool_configuration = ToolConfiguration.create!(
            name: scan_name,
            tool_name: scan_tool
          )

          scan_options.each do |option|
            db_tool_configuration_option = ToolOption.create!(
              name: option["name"],
              value: option["value"]
            )

            db_tool_configuration.tool_options << db_tool_configuration_option
          end


          # tell everyone else about the new job!
          #puts "connected users: #{@connected_users}"
          puts "made scan config!"
          add_scan_config_event_data = {tool_name: scan_tool, name: scan_name, id: db_tool_configuration.id}
          @connected_users[project.id].each do |user|
            user.send('{"event": "add-scan-config", "data": '+add_scan_config_event_data.to_json + "}")
          end
        end

        if msg["event"] == "add-trigger"
          puts "adding trigger!"
          trigger_name = msg["data"]["name"]
          trigger_cmd = msg["data"]["run_shell"]
          trigger_on = msg["data"]["trigger_on"]
          run_in_background = msg["data"]["run_in_background"]
          trigger_conditions = msg["data"]["conditions"]
        
          db_trigger = Trigger.create!(
            user_id: user.id,
            project_id: project.id,
            name: trigger_name,
            trigger_on: trigger_on,
            run_shell: trigger_cmd,
            run_in_background: run_in_background,
            paused: false
          )

          trigger_conditions.each do |condition|
            TriggerCondition.create!(
              trigger_id: db_trigger.id,
              match_key: condition["match_key"],
              match_value: condition["match_value"],
              match_type: condition["match_type"]
            )
          end

          add_trigger_event_data = {
            name: db_trigger.name,
            id: db_trigger.id
          }
          if (@connected_users.key? project.id)
            @connected_users[project.id].each do |user|
              user.send('{"event": "add-trigger", "data": '+add_trigger_event_data.to_json + "}")
            end
          end
        end

        if msg["event"] == "background-trigger"
          puts "backgrounding trigger!"
          trigger_id = msg["data"]["id"]

          db_trigger = Trigger.find(trigger_id.to_i)
          if (db_trigger)
            db_trigger.update_attributes(run_in_background: "t");
            db_trigger.save!
          end

         background_trigger_event_data = {
            id: db_trigger.id,
            name: db_trigger.name
          }
          
          if (@connected_users.key? project.id)
            @connected_users[project.id].each do |user|
              user.send('{"event": "background-trigger", "data": '+background_trigger_event_data.to_json + "}")
            end
          end
        end

        if msg["event"] == "foreground-trigger"
          puts "foregrounding trigger!"
          trigger_id = msg["data"]["id"]

          db_trigger = Trigger.where(id: trigger_id).where(project_id: project.id).first

          if (db_trigger)
            db_trigger.update_attributes(run_in_background: "f");
            db_trigger.save!
          end


         foreground_trigger_event_data = {
            id: db_trigger.id,
            name: db_trigger.name
          }
          if (@connected_users.key? project.id)
            @connected_users[project.id].each do |user|
              user.send('{"event": "foreground-trigger", "data": '+foreground_trigger_event_data.to_json + "}")
            end
          end
        end

        if msg["event"] == "pause-trigger"
          puts "pausing trigger!"
          trigger_id = msg["data"]["id"]

          db_trigger = Trigger.find(trigger_id.to_i)
          if (db_trigger)
            db_trigger.update_attributes(paused: true);
            db_trigger.save!
          end

         paused_trigger_event_data = {
            id: db_trigger.id,
            name: db_trigger.name
          }
          if (@connected_users.key? project.id)
            @connected_users[project.id].each do |user|
              user.send('{"event": "pause-trigger", "data": '+paused_trigger_event_data.to_json + "}")
            end
          end
        end

        if msg["event"] == "unpause-trigger"
          puts "unpausing trigger!"
          trigger_id = msg["data"]["id"]

          db_trigger = Trigger.find(trigger_id)
          if (db_trigger)
            db_trigger.update_attributes(paused: false);
            db_trigger.save!
          end

         unpaused_trigger_event_data = {
            id: db_trigger.id,
            name: db_trigger.name
          }

          if (@connected_users.key? project.id)
            @connected_users[project.id].each do |user|
              user.send('{"event": "unpause-trigger", "data": '+unpaused_trigger_event_data.to_json + "}")
            end
          end
        end

        if (scanloader) # we are the scanloader, get access to some special WS events
          if (msg["event"] == "notify")
            puts "pushing notification"
            message = msg["data"]["message"]
            type = msg["data"]["type"]

            notification_event_data = {
              message: message,
              type: type
            }

            if (@connected_users.key? project.id)
              @connected_users[project.id].each do |user|
                user.send('{"event": "notification", "data": '+ notification_event_data.to_json + "}");
              end
            end
          end

          if (msg["event"] == "update-host")
            update_host_data = {
              id: msg["data"]["id"] # id of host for client browser to update
            }

            if (@connected_users.key? project.id)
              @connected_users[project.id].each do |user|
                user.send('{"event": "update-host", "data": '+ update_host_data.to_json + "}")
              end
            end
          end

          if (msg["event"] == "update-domain")
            update_domain_data = {
              id: msg["data"]["id"] # id of host for client browser to update
            }

            if (@connected_users.key? project.id)
              @connected_users[project.id].each do |user|
                user.send('{"event": "update-domain", "data": '+ update_domain_data.to_json + "}")
              end
            end
          end

          if (msg["event"] == "update-application")
            update_application_data = {
              id: msg["data"]["id"] # id of host for client browser to update
            }

            if (@connected_users.key? project.id)
              @connected_users[project.id].each do |user|
                user.send('{"event": "update-application", "data": '+ update_application_data.to_json + "}")
              end
            end
          end
        end
      end
    end
  end
end
