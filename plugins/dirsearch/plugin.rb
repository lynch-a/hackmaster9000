require_relative '../../ingesters/common.rb'

class DirsearchPlugin < Hm9kPlugin
  
  def self.name
    "dirsearch" # matches plugin folder name, ideally matches binary name like "nmap"
  end
  
  def self.description
    "Brute-force searches website directories"
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

        puts "ingesting dirsearch web app #{scheme}://#{known_name}:#{port} "

        db_web_application = ingest_web_application(project_id, "dirsearch", known_name, scheme, port)

        entries = []

        parsed[url].each do |entry|
          entries << {
            path: entry["path"],
            status: entry["status"],
            content_length: entry["content-length"]
          }
        end

        db_ds_scan = DirsearchScan.find_or_create_by(
          web_application_id: db_web_application.id,
        )
        db_ds_scan.save!

        entries.each do |entry|
          db_ds_result = DirsearchResult.find_or_initialize_by(
            dirsearch_scan_id: db_ds_scan.id,
            path: entry[:path],
            redirect: entry[:redirect],
            status: entry[:status],
            content_length: entry[:content_length]
          )

          if db_ds_result.new_record?
            checkTrigger(
              project_id,
              "dirsearch-result",
              [ # replacers
                ["%url%", url+entry[:path]]
              ], [ # data matchers
                ["path", entry[:path]],
                ["status", entry[:status]],
                ["redirect", entry[:redirect]],
                ["content_length", entry[:content_length]]
              ]
            )

          end
          db_ds_result.save!
        end  # end each-entry
      end
    end
end