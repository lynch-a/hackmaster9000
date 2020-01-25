require_relative 'common.rb'

def ingest_nmap_host_script(project_id, host_id, script_name, script_output)
  db_host_script = HostScript.find_or_initialize_by(
    host_id: host_id,
    script_id: script_name,
    script_output: script_output
  )
  
  db_host = Host.where(project_id: project_id.id, id: host_id).first

  if (db_host_script.new_record?)
    checkTrigger(
      "script",
      [["%ip%", db_host.ip]],
      [["script-name", script_name], ["script-output", script_output]]
    )
  end
  db_host_script.save
end