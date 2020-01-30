require_relative 'common.rb'

def ingest_host(project_id, source_plugin, ip)
  ip = ip.strip
  if !!!(ip =~ /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/)
    puts "PANIC: ingest_host not provided  an IP address."
    return nil
  end

  db_host = Host.find_or_initialize_by(project_id: project_id, ip: ip)

  if db_host.new_record?
    checkTrigger(
      project_id,
      "add-host",
      [["%ip%", ip]],
      []
    )
    db_host.save!
    update_host_feed(db_host, source_plugin, "unused", "discovered new host: #{ip}")
    # todo: update this to store the source filename
  else
    db_host.save!
    update_host_feed(db_host, source_plugin, "unused", "discovered duplicate host: #{ip}" )
  end

  puts "[#{source_plugin}] Host ingested: #{db_host.id} - #{db_host.ip}"
  return db_host
end