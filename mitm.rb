require 'evil-proxy'
require './db.rb'

### ingestors

def ingest_web_application(dns_name, scheme, port)
  puts "web app ingest start"
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
    project_id: 2,
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

  db_host = Host.find_or_initialize_by(project_id: 2, ip: ip)

  if db_host.new_record?
    #puts "INGEST NEW HOST"

    # check for triggers
    #checkTrigger(
    #  "add-host",
    #  [["%ip%", ip]],
    #  []
    #)

    # potentially notify
  end

  db_host.save
  #send_host_refresh(db_host.id)

  return db_host
end

def ingest_service(host_id, port, name, product, version, confidence)
  db_service = Service.find_or_initialize_by(
    host_id: host_id,
    port_number: port,
    project_id: 2
  )

  if db_service.new_record?
    #checkTrigger(
    #  "add-service",
    #  [
    #    ["%ip%", Host.where(id: host_id).first.ip],
    #    ["%port%", port]
    #  ], [
    #    ["port", port]
    #  ]
    #)
  end

  db_service.update_attributes!(
    service_name: name,
    service_product: product,
    service_version: version,
    service_confidence: confidence,
  )

  db_service.save!

  return db_service
end

def ingest_domain(dns_name, record_type, record_value)
   puts "domain ingest start"
    # if ip is given, we check if we have a record_value
  if dns_name == ""
    #puts "ingesting ghost domain from ip: #{record_value}"

    db_dns_record = DnsRecord.find_or_initialize_by(
      project_id: 2,
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
      project_id: 2,
      dns_name: dns_name,
      record_type: "A"
    )

    if (db_dns_record.new_record?)
      if (!db_dns_record.dns_name.nil?)
        #checkTrigger(
        #  "add-domain",
        #  [["%domain%", dns_name]],
        #  [["domain", dns_name]] # check against all of the "domain" match keys in the conditions
        #)
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
      project_id: 2,
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
      project_id: 2,
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
        project_id: 2,
        dns_name: dns_name,
        record_type: "A"
      ).first

      if (db_dns_record) # we found a record by the given dns_name
        new_dns_name_flag = false
      end

      db_dns_record = DnsRecord.find_or_initialize_by(
        project_id: 2,
        dns_name: dns_name,
        record_type: "A",
        record_value: record_value
      )

      if (db_dns_record.new_record? and new_dns_name_flag)
        #checkTrigger(
        #  "add-domain",
        #  [["%domain%", dns_name], "%ip%", record_value],
        #  [["domain", dns_name]] # check against all of the "domain" match keys in the conditions
        #)
        db_dns_record.save
        
        #send_domain_refresh(db_dns_record.id)
      end
    end
  end
  return db_dns_record
end

def ingest_page(web_application_id, request_relative_path)
  db_page = Page.find_or_initialize_by(
    web_application_id: web_application_id,
    path: request_relative_path,
  )

  if db_page.new_record?
    #checkTrigger(
    #  "add-page",
    #  [
    #    ["%ip%", Host.where(id: host_id).first.ip],
    #    ["%port%", port]
    #  ], [
    #    ["port", port]
    #  ]
    #)
  end

  db_page.save!

  return db_page
end

def ingest_input(page_id, parameter_name, parameter_value, http_method)
  db_input = Input.find_or_initialize_by(
    page_id: page_id,
    name: parameter_name,
    value: parameter_value,
    http_method: http_method
  )

  if db_input.new_record?
    #checkTrigger(
    #  "add-page",
    #  [
    #    ["%ip%", Host.where(id: host_id).first.ip],
    #    ["%port%", port]
    #  ], [
    #    ["port", port]
    #  ]
    #)
  end

  db_input.save!
  return db_input
end

def ingest_header(page_id, header_name, header_value)
  db_header = Header.find_or_initialize_by(
    page_id: page_id,
    name: header_name,
    value: header_value,
  )

  if db_header.new_record?
    #checkTrigger(
    #  "add-page",
    #  [
    #    ["%ip%", Host.where(id: host_id).first.ip],
    #    ["%port%", port]
    #  ], [
    #    ["port", port]
    #  ]
    #)
  end

  db_header.save!
  return db_header
end

### ingestors end

# EvilProxy::HTTPProxyServer is a subclass of Webrick::HTTPProxyServer;
#   it takes the same parameters.

proxy = EvilProxy::HTTPProxyServer.new Port: 40123

proxy.before_request do |request|
  # Do evil things
  # Note that, different from Webrick::HTTPProxyServer, 
  #   `req.body` is writable.
  #next if (request.request_method == "CONNECT")
  scheme_ = "https"

  begin
    if request.ssl?
      puts "USING HTTPS"
      scheme_ = "https"
    else 
      puts "USING HTTP"
      scheme_ = "http"
    end
  rescue Exception => e
    puts "still unable to use request.ssl: #{e.message}"
    scheme_ = "http"
  end

  next if request.host() == "" or request.host() == nil
  next if scheme_ == "problem"

  web_app = ingest_web_application(request.host(), scheme_, request.port())
  
  page = ingest_page(web_app.id, request.path())

  puts "----REQ:"
  puts request.host()
  puts request.request_method
  puts scheme_
  puts request.body
  puts request.query_string
  puts "----"

  if request.request_method == "GET"

    puts "full req:"
    next if request.query_string = ""
    params = WEBrick::HTTPUtils.parse_query(request.query_string)
    params.each {|key, value|
      key = "" if key == nil
      value = "" if value == nil
      puts "INGESTING INPUT KEY: #{key} VALUE: #{value}"
      begin
        ingest_input(page.id, key, value, "GET")
      rescue
        puts "failed to parse querystring: #{request.query_string}"
      end
    } 
  elsif request.request_method == "POST"
    puts "full req:"
    next if request.query_string == ""
    params = WEBrick::HTTPUtils.parse_query(request.body)
    params.each {|key, value|
      key = "" if key == nil
      value = "" if value == nil
      puts "INGESTING POST INPUT KEY: #{key} VALUE: #{value}"
      begin
        ingest_input(page.id, key, value, "POST")
      rescue
        puts "failed to parse querystring: #{request.query_string}"
      end
    } 
  end

  # associate header data with it, too
  request.each {|header, value|
    header = "" if header == nil
    value = "" if value == nil
    ingest_header(page.id, header, value)
  }

  puts "should have parsed: #{request.host()}"
end

proxy.before_response do |req, res|
  # Here `res.body` is also writable.
end

trap "INT"  do proxy.shutdown end
trap "TERM" do proxy.shutdown end

proxy.start