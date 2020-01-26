class ZmapPlugin < Hm9kPlugin
  
  def self.name
    "zmap" # matches plugin folder name, ideally matches binary name like "nmap"
  end
  
  def self.description
    "Zmap is a fast, internet-scope port scanner capable of sending gigabites of traffic."
  end

  def self.partial
    "_zmap" # the path to the partial file, which should be in this plugin directory, without ".erb" at the end
  end

  def self.file_filter
    "zmap-*.csv" # file filter
  end

  def self.visualize_in_hosts?
    true
  end
  
  def self.host_feed_partial
    "_host_feed"
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

  # Write this method. Any project files matching the file_filter above will have their full pathname passed to this parse method in the file_path argument.
  def self.parse(project_id, file_path)
    CSV.foreach(file_path, headers: true) do |row|
      ip = row['saddr']
      port = row['sport']

      db_host = ingest_host(project_id, 'zmap', ip)
      ingest_service(project_id, db_host.id, port, "zmap", "", "", "")
    end
  end
end