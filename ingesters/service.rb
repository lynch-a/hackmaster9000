require_relative 'common.rb'

def ingest_service(project_id, host_id, port, name, product, version, confidence)
  db_service = Service.find_or_initialize_by(
    host_id: host_id,
    port_number: port,
    project_id: project_id
  )

  puts "ingesting service: #{host_id} #{port} #{name} #{product}"
  if db_service.new_record?
    checkTrigger(
      project_id,
      "add-service",
      [
        ["%ip%", Host.find(host_id).ip], # hopefully hosts are ingested before the service
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