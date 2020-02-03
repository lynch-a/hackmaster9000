require_relative 'common.rb'

def ingest_dns_record(project_id, source_plugin, record_key, record_type, record_value)
  record_value = record_value.strip.gsub(/\.$/, '').strip # filter dots after record value like: (domain.com.)

  db_dns_record = DnsRecord.find_or_initialize_by(
      project_id: project_id,
      record_key: record_key,
      record_type: record_type,
      record_value: record_value
    )

    if (db_dns_record.new_record?)
      db_dns_record.update_attributes(source_plugin: source_plugin)
      db_dns_record.save!
      update_dns_record_feed(db_dns_record, source_plugin, "unused", "discovered new DNS record: #{record_key} #{record_type} #{record_value}")
    else
      update_dns_record_feed(db_dns_record, source_plugin, "unused", "discovered duplicate DNS record: #{record_key} #{record_type} #{record_value}")
    end

  # is this an A or CNAME record? add it as a domain
  if record_type == "A" or record_type == "CNAME"
    db_domain = ingest_domain(project_id, source_plugin, record_key)
  end

  puts "ingested DNS record: #{source_plugin}, key:#{record_key}, type:#{record_type}, value:#{record_value}"
  return db_dns_record
end
