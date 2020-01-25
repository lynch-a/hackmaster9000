require_relative 'common.rb'

def ingest_nmap_service_script(project_id, service_id, dns_records, script_name, script_output)
  db_service_script = ServiceScript.find_or_initialize_by(
    project_id: project_id,
    service_id: service_id,
    script_id: script_name,
    script_output: script_output
  )

  db_service = Service.where(id: service_id).first

  if db_service_script.new_record?
    #puts "NEW SERVICE SCRIPT"
    dns_records.each do |dns_record|
      checkTrigger(
        project_id,
        "script",
        [
          ["%ip%", db_service.host.ip],
          ["%port%", db_service.port_number],
          ["%domain%", dns_record.record_key ]
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
        project_id,
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