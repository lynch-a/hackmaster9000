require 'csv'

class SpiderfootPlugin < Hm9kPlugin
  
  def self.name
    "spiderfoot" # matches plugin folder name
  end

  def self.description
    "Automatic OSINT scanning engine" # short description of underlying utility
  end

  # does this plugin include a html/js tool running interface?
  def self.has_tool_ui?
    return true
  end

  # what is the filename for the ERB partial (without .erb at the end) that has the the tool interface?
  def self.partial
    "_spiderfoot"
  end

  # what filenames should this plugin parse?
  def self.file_filter
    "sf-*.csv" # files
  end

  # does this plugin include extra useful data that should be attached to a host?
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

    CSV.foreach(file_path, headers: false, col_sep: "|||") do |row|
      next if row.size == 3

      puts row.inspect
      type = row[1].strip
      target = row[2].strip
      value = row[3].strip
      puts "checking spiderfoot: type: #{type} target: #{target} value: #{value}"

      begin
        if type == "IP Address"
          ingest_host(project_id, "spiderfoot", value)
        elsif type == "Domain Name"
          ingest_dns_record(project_id, "spiderfoot", value, "A", "UNRESOLVED")
        elsif type == "Internet Address"

        elsif type == "Internet Name"
          ingest_dns_record(project_id, "spiderfoot", value, "A", "UNRESOLVED")
        end
      rescue => e
        puts "spiderfoot failed and we are ignoring it: #{e.backtrace}"
        return false
      end
    end
    
    return true # just assume it worked
  end
end



