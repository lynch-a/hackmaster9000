require 'nmap/parser'

class NmapPlugin < Hm9kPlugin
  
  def self.name
    @name = "nmap" # matches plugin folder name
  end

  def self.description
    @meta = "A popular network mapping tool." # short description of underlying utility
  end

  def self.partial
    "_nmap"
  end

  def self.file_filter
    "nmap-*.xml" # files
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

  def self.parse(project_id, file_path)
    file_contents = File.read(file_path)

    file_shortname = File.basename(file_path)

    # we use the nmap parser gem
    parser = Nmap::Parser.parsestring(file_contents)

    parser.hosts("up") do |nmap_host|
      db_host = ingest_host(project_id, "nmap", nmap_host.ipv4_addr)

      nmap_host.scripts do |nmap_script|
        ingest_nmap_host_script(project_id, db_host.id, nmap_script.id, nmap_script.output)
      end
      
      db_dns_records = []
      nmap_host.hostnames().each do |nmap_hostname|
        # falsely assumes nmap reverse host resolution is an actual A record
       db_dns_record = ingest_dns_record(project_id, "nmap", nmap_hostname, "A", nmap_host.ipv4_addr)
       db_dns_records << db_dns_record
      end

      [:tcp, :udp].each do |type|
        nmap_host.getports(type, "open") do |nmap_port|
          nmap_service = nmap_port.service

          db_service = ingest_service(project_id, db_host.id, nmap_port.num, nmap_service.name, nmap_service.product, nmap_service.version, nmap_service.confidence)

          nmap_port.scripts do |nmap_script|
            ingest_nmap_service_script(project_id, db_service.id, db_dns_records, nmap_script.id, nmap_script.output)
          end
        end
      end
    end

    "true" # just assume it worked
  end
end



