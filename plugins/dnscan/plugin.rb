class DnscanPlugin < Hm9kPlugin
  
  def self.name
    "dnscan" # matches plugin folder name, ideally matches binary name like "nmap"
  end
  
  def self.description
    "Brute-force domain names"
  end

  def self.has_tool_ui?
    return true
  end
  
  def self.partial
    "_dnscan" # the path to the partial file, which should be in this plugin directory, without ".erb" at the end
  end

  def self.file_filter
    "dnscan-*.txt" # file filter
  end

  def self.visualize_in_hosts?
    false
  end

  def self.visualize_in_dns_records?
    false
  end

  def self.dns_record_feed_partial
    "_dns_record_feed"
  end

  def self.visualize_in_domains?
    false
  end

  def self.domain_feed_partial
    "_domain_feed"
  end

  def self.visualize_in_web_applications?
    false
  end

  # Write this method. Any project files matching the file_filter above will have their full pathname passed to this parse method in the file_path argument.
  def self.parse(project_id, file_path)
    file_contents = File.read(file_path)

    flag = false # are we parsing A records yet
    domains_created = 0
    file_contents.each_line do |line|
      if !flag
        if !line.include? "for A records"
          next
        else
          flag = true
          next
        end
      end

      # parsing A records below

      # check if there's a [, stop parsing A records if there is
      if line[0] == "["
        return
      end

      next if line.blank?

      #puts "PARSING DNSCAN LINE: #{line}"
      data = line.split(" - ")
      ip_addr = data[0]
      dns_name = data[1].strip

      db_dns_record = ingest_dns_record(project_id, "dnscan", dns_name, "A", ip_addr)
      db_host = ingest_host(project_id, "dnscan", ip_addr)

      #send_host_refresh(db_host.id)
      #send_domain_refresh(db_dns_record.id)
    end
    return "true"
  end
end