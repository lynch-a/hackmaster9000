class DigPlugin < Hm9kPlugin
  
  def self.name
    @name = "dig" # matches plugin folder name
  end

  def self.description
    @meta = "domain information groper" # short description of underlying utility
  end

  def self.has_tool_ui?
    return true
  end
  
  def self.partial
    "_dig"
  end

  def self.file_filter
    "dig-*.txt"
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

    flag = false # are we parsing A records yet
    dns_records_parsed = 0
    file_contents.each_line do |line|
      if !flag
        if !line.include? ";; ANSWER SECTION:"
          next
        else
          flag = true
          next
        end
      end

      # parse out dig DNS answer section

      # check if there's a ;, stop parsing if there is
      if line[0] == ";"
        return true
      end

      next if line.blank?

      data = line.gsub(/\s+/m, ' ').strip.split(" ")

      record_key = data[0].strip.gsub(/\.$/, '').strip

      sometimer = data[1].strip
      always_in = data[2].strip
      record_type = data[3].strip
      record_value = data[4].strip

      puts data.inspect

      db_dns_record = ingest_dns_record(project_id, "dig", record_key, record_type, record_value)
      
      # we know this is a host (but not necessarily that it's alive)
      if record_type == "A"
        db_host = ingest_host(project_id, "dig", record_value)
      end
    end

    return true
  end
end