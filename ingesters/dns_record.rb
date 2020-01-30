require_relative 'common.rb'

def ingest_dns_record(project_id, source_plugin, record_key, record_type, record_value)
  record_value = record_value.strip.gsub(/\.$/, '').strip

  db_dns_record = DnsRecord.find_or_initialize_by(
    project_id: project_id,
    record_key: record_key,
    record_type: record_type,
    record_value: record_value
  )

  if (db_dns_record.new_record?)
    # we really don't want to check for triggers here because some of the tools make fake A records for now 
    #checkTrigger(
    #  project_id,
    #  "add-domain",
    #  [
    #    ["%domain%", db_domain.domain_name], # hopefully hosts are ingested before the service
    #  ], [
    #    ["domain", db_domain.domain_name]
    #  ]
    #)
    db_dns_record.update_attributes(source_plugin: source_plugin)
    db_dns_record.save!
    update_dns_record_feed(db_dns_record, source_plugin, "unused", "discovered new DNS record: #{record_key} #{record_type} #{record_value}")
  else
    update_dns_record_feed(db_dns_record, source_plugin, "unused", "discovered duplicate DNS record: #{record_key} #{record_type} #{record_value}")
  end

  # is this an A record? is a domain made for it? if not, make one
  if record_type == "A" or record_type == "CNAME"
    db_domain = Domain.find_or_initialize_by(project_id: project_id, domain_name: record_key)
  
    if db_domain.new_record?
      checkTrigger(
        project_id,
        "add-domain",
        [
          ["%domain%", db_domain.domain_name] # hopefully hosts are ingested before the service
        ], [
          ["domain", db_domain.domain_name]
        ]
      )

      db_domain.update_attributes(source_plugin: source_plugin)
      puts "Ingested new domain: #{db_domain.domain_name}"
    else
      # this won't overwrite the source plugin
      puts "Ingested old domain: #{db_domain.domain_name}"
    end
    
    if db_domain.domain_name.count(".") == 1
      db_domain.update_attributes(tld: true)
    else
      db_domain.update_attributes(tld: false)
    end
    
    db_domain.save!

  end



  db_dns_record.save!
  puts "ingested DNS record: #{source_plugin}, key:#{record_key}, type:#{record_type}, value:#{record_value}"
  return [db_dns_record, db_domain]
end
