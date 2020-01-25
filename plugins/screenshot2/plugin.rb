class Screenshot2Plugin < Hm9kPlugin
  
  def self.name
    "screenshot2" # matches plugin folder name, ideally matches binary name like "nmap"
  end
  
  def self.description
    "A custom PhantomJS headless screenshotter. It's kinda fast."
  end

  def self.partial
    "_screenshot2" # the path to the partial file, which should be in this plugin directory, without ".erb" at the end
  end

  def self.file_filter
    "ss2-*.txt" # file filter
  end

  def self.visualize_in_hosts?
    false
  end

  def self.visualize_in_dns_records?
    false
  end

  def self.visualize_in_domains?
    true
  end

  def self.domain_feed_partial
    "_domain_feed"
  end

  def self.visualize_in_web_applications?
    true
  end

  # Write this method. Any project files matching the file_filter above will have their full pathname passed to this parse method in the file_path argument.
  def self.parse(project_id, file_path)
    file_contents = File.read(file_path)

    file_contents.each_line do |line|
      line = line.split(" ")
      next if (line.length !=  3) # remove lines with no ip

      scheme = line[0]
      domain = line[1]
      port = line[2]

      db_web_application = ingest_web_application(project_id, "screenshot2", domain, scheme, port)

      #send_web_application_refresh(db_web_application.id)
    end
  end
end