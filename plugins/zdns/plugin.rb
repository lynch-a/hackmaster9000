class ZdnsPlugin < Hm9kPlugin
  
  def self.name
    @name = "zdns" # matches plugin folder name
  end

  def self.description
    @meta = "test." # short description of underlying utility
  end

  def self.has_tool_ui?
    return false
  end

  def self.partial
    ""
  end

  def self.file_filter
    "zdns-*.txt" # files
  end

  def self.visualize_in_hosts?
    false
  end

  def self.visualize_in_dns_records?
    false
  end

  def self.visualize_in_domains?
    false
  end

  def self.visualize_in_web_applications?
    false
  end

  def self.parse(project_id, file_path)
    file_contents = File.read(file_path)
        
    file_contents.each_line do |line|
      next if (line.length <  4) # garbo
      next if line.include? "NO_ANSWER"
    
      parsed = JSON.parse(line.strip!)
      name = parsed["name"]
      status = parsed["status"]

      if status == "NOERROR"
        ip = parsed["data"]["ipv4_addresses"][0]

        ingest_dns_record(project_id, "zdns", name, "A", ip)
        ingest_host(project_id, "zdns", ip) # maybe
      end
    end
    return true # just assume it worked
  end
end



