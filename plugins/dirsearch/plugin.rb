require_relative '../../ingesters/common.rb'

class DirsearchPlugin < Hm9kPlugin
  
  def self.name
    "dirsearch" # matches plugin folder name, ideally matches binary name like "nmap"
  end
  
  def self.description
    "Brute-force searches website directories"
  end

  def self.has_tool_ui?
    return true
  end
  
  def self.partial
    "_dirsearch" # the path to the partial file, which should be in this plugin directory
  end

  def self.file_filter
    "dirsearch-*.json" # file filter
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

  def self.domain_feed_partial
    "_domain_feed_entry"
  end

  def self.visualize_in_web_applications?
    true
  end

  def self.web_application_feed_partial
    "_domain_feed_entry"
  end

  # Write this method. Any project files matching the file_filter above will have their full pathname passed to this parse method in the file_path argument.
  def self.parse(project_id, file_path)
    file_contents = File.read(file_path)

    # we manually parse this JSON
    parsed = JSON.parse(file_contents)

    parsed.keys.each do |url|
      parsed_url = URI(url)
      known_name = parsed_url.host # this could either be an IP or a domain name (and not necessarily a DNS record) so ingesting it poses problems.
      scheme = parsed_url.scheme
      port = parsed_url.port

      puts "[dirsearch] ingesting web app #{scheme}://#{known_name}:#{port} "

      db_web_application = ingest_web_application(project_id, "dirsearch", known_name, scheme, port)

      entries = []

      parsed[url].each do |entry|
        entries << {
          path: entry["path"],
          status: entry["status"],
          content_length: entry["content-length"],
          redirect: entry["redirect"]
        }
      end

      entries.each do |entry|
        puts "ingesting page: pid: #{project_id} appid: #{db_web_application.id} path: #{entry[:path]}, CL: #{entry[:content_length]}, status: #{entry[:status]} redirect: #{entry[:redirect]}"
        db_page = ingest_page(project_id,
          db_web_application.id,
          "dirsearch",
          entry[:path],
          entry[:content_length],
          entry[:status],
          entry[:redirect]
        )
        puts "[dirsearch] ingested page: #{db_page.path} CL: #{db_page.content_length}, status: #{db_page.status}, redirect: #{db_page.redirect}"
      end
    end
  end
end
