require_relative 'common.rb'
require 'resolv'

def ingest_web_application(project_id, source_plugin, known_name, scheme, port)
  # these will all be set to values by the end of this method, just making scope clear
  db_host = nil
  db_domain = nil
  db_service = nil

  if !!(known_name =~ /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/)
    db_host = ingest_host(project_id, source_plugin, known_name)
    db_service = ingest_service(project_id, db_host.id, port, scheme, "", "", "")
  else # a domain name was provided
    cheat_ip = Resolv.getaddress(known_name) # resolve the domain ourselves
    db_domain = ingest_dns_record(project_id, source_plugin, known_name, "A", cheat_ip)[1]
    db_host = ingest_host(project_id, source_plugin, cheat_ip)
    db_service = ingest_service(project_id, db_host.id, port, scheme, "", "", "")
  end

  db_web_application = WebApplication.find_or_initialize_by(
    project_id: project_id,
    scheme: scheme,
    host_id: db_host.id,
    service_id: db_service.id
  )

  if (!db_domain.nil?)
    db_web_application.update_attributes(domain_id: db_domain.id)
  end

  if db_web_application.new_record?
    if db_service.new_record?
      checkTrigger(
        project_id,
        "add-web-application",
        [
          ["%full_url%", db_web_application.full_url] # hopefully hosts are ingested before the service
        ], [
          ["full_url", db_web_application.full_url],
          ["port", port]
        ]
      )
    end

    db_web_application.save!
    #puts "ingested new web app: #{Domain.find(db_web_application.domain_id).domain_name}"
  else
    #puts "ingested duplicate web app (not adding): #{Domain.find(db_web_application.domain_id).domain_name}"
  end

  return db_web_application
end