require_relative '../../ingesters/common.rb'
require 'fileutils'

class TestsslPlugin < Hm9kPlugin
  
  def self.name
    @name = "testssl" # matches plugin folder name
  end

  def self.description
    @meta = "Test the encryption and cipher suites used by a host" # short description of underlying utility
  end

  # does this plugin include a html/js tool running interface on Hackmaster9000?
  def self.has_tool_ui?
    return true
  end

  # what is the filename for the ERB partial (without .erb at the end) that has the the tool interface?
  def self.partial
    "_testssl"
  end

  # what filenames should this plugin parse?
  def self.file_filter
    "testssl-*.json" # files
  end

  # does this plugin include extra useful data that should be attached to a host?
  def self.visualize_in_hosts?
    true
  end

  # if so, what is the filename for the ERB partial (without .erb at the end) for the extra data?
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

  def self.parse(project_id, file_path)
    file_contents = File.read(file_path)

    file_shortname = File.basename(file_path)
    html_file_shortname = file_shortname.gsub("\.json", "\.html")

    begin
      parsed = JSON.parse(file_contents)

      parsed["scanResult"].each do |scan_result|
        ip = scan_result["ip"].strip
        domain_name = scan_result["targetHost"].strip
        port = scan_result["port"].strip

        puts "testssl found: #{ip} #{domain_name} #{port}"

        if !!!(domain_name =~ /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/)
          # ingest a dns record if it exists for the testssl scan result
          ingest_dns_record(project_id, "testssl", domain_name, "A", ip)
        end

        db_host = ingest_host(project_id, "testssl", ip)
        ingest_service(project_id, db_host.id, port, "testssl", "", "", "")

        update_host_feed(db_host, "testssl", "testssl_result", html_file_shortname)
      end
    rescue => e
      return false
    end

    FileUtils.move("hm9k-projects/#{Project.find(project_id).uuid}/#{html_file_shortname}", "public/#{html_file_shortname}")

    return true
  end
end



