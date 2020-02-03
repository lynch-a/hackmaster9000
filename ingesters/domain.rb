require_relative 'common.rb'

def ingest_domain(project_id, source_plugin, domain_name)
  db_domain = Domain.find_or_initialize_by(project_id: project_id, domain_name: domain_name)

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

  puts "ingested domain: #{domain_name}"
  return db_domain
end
