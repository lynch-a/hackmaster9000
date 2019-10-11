require 'active_record'
require 'bcrypt'
require 'securerandom'
require 'textacular'

ActiveRecord::Base.extend(Textacular)

ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  database: "hm9k",
  host: $database_host,
  username: $database_username,
  password: $database_password,
  timeout: 150000,
  pool: 1000 # lol
)

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'web_applications'
    create_table :web_applications do |table|
      table.column :project_id, :int
      table.column :name, :string
      table.column :description, :string
      table.column :port, :int
      table.column :scheme, :string # http, https
      table.column :risk, :int, default: 0
      table.column :dns_record_id, :int
      table.column :hidden, :boolean, default: false
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'pages'
    create_table :pages do |table|
      table.column :web_application_id, :int
      table.column :path, :string
      table.column :description, :string
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'inputs'
    create_table :inputs do |table|
      table.column :page_id, :int
      table.column :name, :string
      table.column :value, :string
      table.column :http_method, :string
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'headers'
    create_table :headers do |table|
      table.column :page_id, :int
      table.column :name, :string
      table.column :value, :string
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'tool_configurations'
    create_table :tool_configurations do |table|
      table.column :name, :string
      table.column :tool_name, :string
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'tool_options'
    create_table :tool_options do |table|
      table.column :name, :string
      table.column :value, :string
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'tool_configurations_options'
    create_table :tool_configurations_options do |table|
      table.column :tool_configuration_id, :int
      table.column :tool_option_id, :int
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'users'
    create_table :users do |table|
      table.column :username, :string
      table.column :password_hash, :string
      table.column :session_key, :string
      table.column :session_expires, :datetime

      table.column :email, :string
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'projects'
    create_table :projects do |table|
      table.column :name, :string
      table.column :uuid, :string
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'terminals'
    create_table :terminals do |table|
      table.column :tid, :string
      table.column :user_id, :int
      table.column :project_id, :int
      table.column :name, :string
      table.column :ordinal, :int
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'hosts'
    create_table :hosts do |table|
      table.column :ip, :string
      table.column :risk, :int, default: 0
      table.column :os, :string
      # low = 0
      # med = 1
      # high = 2
      # unreviewed = nil
      table.column :reviewed, :boolean, default: false
      table.column :ordinal, :integer, default: 0
      table.column :note, :string, default: ""
      table.column :project_id, :integer
      table.column :hidden, :boolean, default: false

    end
  end
end


ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'feed_items'
    create_table :feed_items do |table|
      table.column :data_id, :integer
      table.column :data_type, :integer
      table.column :header, :string
      table.column :value, :string
    end
  end
end

=begin
ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'host_details'
    create_table :host_details do |table|
      table.column :host_id, :int
      table.column :header, :string
      table.column :render_type, :string # "pre, erb"
      table.column :value, :string
      # value:
      # if type is pre, return flat text and put it in a pre
      # if type is erb, render an erb with :value as the path to render.. lol
    end
  end
end
=end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'host_scripts'
    create_table :host_scripts do |table|
      table.column :host_id, :int
      table.column :script_id, :string
      table.column :script_output, :string
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'service_scripts'
    create_table :service_scripts do |table|
      table.column :service_id, :int
      table.column :script_id, :string
      table.column :script_output, :string
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'triggers'
    create_table :triggers do |table|
      table.column :project_id, :int
      table.column :user_id, :int
      table.column :trigger_on, :string # add-host, add-domain, add-service
      table.column :name, :string
      table.column :run_shell, :string
      table.column :run_in_background, :string
      table.column :note, :string
      table.column :paused, :boolean
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'trigger_conditions'
    create_table :trigger_conditions do |table|
      table.column :trigger_id, :int
      table.column :match_key, :string # ex: "port"
      table.column :match_value, :string # ex: "80,443"
      table.column :match_type, :string # "direct", "csv", "regex"
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'services'
    create_table :services do |table|
      table.column :risk, :integer, default: 0
      # low = 0
      # med = 1
      # high = 2
      # unreviewed = nil
      table.column :port_number, :integer
      table.column :service_name, :string
      table.column :service_version, :string
      table.column :service_product, :string
      table.column :service_confidence, :integer
      table.column :ordinal, :integer, default: 0
      table.column :note, :string, default: ""

      table.column :web_application_id, :integer
      table.column :host_id, :integer
      table.column :project_id, :integer
      #table.column :vnc, :boolean
      #table.column :vnc_creds, :string
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'terminals_users'
    create_table :terminals_users do |table|
      table.column :terminal_id, :integer
      table.column :user_id, :integer
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'projects_terminals'
    create_table :projects_terminals do |table|
      table.column :project_id, :integer
      table.column :user_id, :integer
      table.column :terminal_id, :integer
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'projects_users'
    create_table :projects_users do |table|
      table.column :project_id, :integer
      table.column :user_id, :integer
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'dirsearch_results'
    create_table :dirsearch_results do |table|
      table.column :content_length, :integer
      table.column :path, :string
      table.column :redirect, :string
      table.column :status, :string
      table.column :dirsearch_scan_id, :integer
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'dirsearch_scans'
    create_table :dirsearch_scans do |table|
      table.column :web_application_id, :integer
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'dns_records'
    create_table :dns_records do |table|
      table.column :dns_name, :string
      table.column :record_type, :string
      table.column :record_value, :string
      table.column :risk, :integer, default: 0 
      table.column :project_id, :integer
      table.column :note, :string, default: ""
      table.column :hidden, :boolean, default: false
    end
  end
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'jobs'
    create_table :jobs do |table|
      table.column :user_id, :integer
      table.column :project_id, :integer
      table.column :tid, :string # terminal ID associated with job (is set by the terminal server)
      table.column :job_type, :string
      table.column :job_data, :string
      table.column :run_every, :integer
      table.column :last_run, :integer
      table.column :max_runtimes, :integer
      table.column :run_times, :integer
      table.column :status, :string # "queued", "running", "finished"
      table.column :paused, :boolean # if true, don't run the job
      table.column :run_in_background, :string # "t" or "f"
    end
  end
end

class WebApplication < ActiveRecord::Base
  belongs_to :dns_record
  has_many :pages

  def self.by_host_or_record(project_id, host, record)
    WebApplication.where(project_id: project_id, record_value: host.ip)
  end
end

class Page < ActiveRecord::Base
  has_many :inputs
  has_many :headers
  belongs_to :web_application
end

class Input < ActiveRecord::Base
  belongs_to :page
end

class Header < ActiveRecord::Base
  belongs_to :page
end

class Job < ActiveRecord::Base

end

class Service < ActiveRecord::Base
  belongs_to :host
  belongs_to :project
end

class DirsearchResult < ActiveRecord::Base
  belongs_to :dirsearch_scan
end

class DnsRecord < ActiveRecord::Base
  belongs_to :project
  has_many :dirsearch_scans
  has_many :web_applications

  # DnsRecord.by_host(some_host)
  # - return all DNS records where the record_value matches the host ip
  def self.by_host(project_id, host)
    DnsRecord.where(project_id: project_id, record_value: host.ip, hidden: false).group(:dns_name).uniq
  end

  def self.all_A_records(project_id)
    DnsRecord.where(project_id: project_id, record_type: "A", hidden: false).all
  end

  def self.unique_hostnames(project_id)
    DnsRecord.where(project_id: project_id, hidden: false).uniq
  end
end

class VncEntry < ActiveRecord::Base
  belongs_to :service
end

class DirsearchScan < ActiveRecord::Base
  belongs_to :web_application
  has_many :dirsearch_results
end

class Project < ActiveRecord::Base
  has_and_belongs_to_many :users
  has_and_belongs_to_many :terminals, join_table: "projects_terminals"

  has_many :dns_records

  validates :name, uniqueness: true
end

class FeedItem < ActiveRecord::Base
end

class Host < ActiveRecord::Base
  has_many :services
  has_many :host_details
  belongs_to :project

  # return host objects that have DNS records
  def self.by_dns(project_id, dns_name)
    # find all objects with a given dns_name for a given project
    ret = []

    dns_names = DnsRecord.where(project_id: project_id, hidden: false).where(record_type: ["A", "nmap"], dns_name: dns_name).all

    dns_names.each do |dns_name|
      # todo: this doesn't work for cnames... should it?
      somehost = Host.where(project_id: project_id).where(ip: dns_name.record_value).first

      if somehost and !ret.include? somehost
        ret << somehost
      end
    end

    return ret
  end
end

class HostScript < ActiveRecord::Base
  belongs_to :host
end

class ServiceScript < ActiveRecord::Base
  belongs_to :host
end

class User < ActiveRecord::Base
  has_and_belongs_to_many :projects, join_table: "projects_terminals"
  has_and_belongs_to_many :terminals, join_table: "terminals_users"


  validates :username, uniqueness: true

  include BCrypt
  
  def password
    @password ||= Password.new(password_hash)
  end

  def password=(new_password)
    @password = Password.create(new_password)
    self.password_hash = @password
  end

  def make_session()
    self.update_attribute(:session_key, SecureRandom.hex(64))
    self.update_attribute(:session_expires, Time.now + 60 * 60 * 24 * 7) # 7 day expire
  end

  # check if not expired
  def valid_session?(sid)
    return true # lol
  end
end

class ProjectsUsers < ActiveRecord::Base
    belongs_to :project
    belongs_to :user
end

class ToolConfiguration < ActiveRecord::Base
  has_and_belongs_to_many :tool_options, join_table: "tool_configurations_options"
end

class ToolConfigurationsOptions < ActiveRecord::Base
  belongs_to :tool_configuration
  belongs_to :tool_option
end

class ToolOption < ActiveRecord::Base
  has_and_belongs_to_many :tool_configurations, join_table: "tool_configurations_options"
end

class Trigger < ActiveRecord::Base
  belongs_to :project
  belongs_to :user
  has_many :trigger_conditions
end

class TriggerCondition < ActiveRecord::Base
  belongs_to :trigger
end

class Terminal < ActiveRecord::Base
  has_and_belongs_to_many :projects, join_table: "projects_terminals"
  has_and_belongs_to_many :users, join_table: "terminals_users"
end

class ProjectsTerminals < ActiveRecord::Base
  belongs_to :project
  belongs_to :terminal
end

class TerminalsUsers < ActiveRecord::Base
  belongs_to :terminal
  belongs_to :user
end

if User.all.size < 1
  # first run; create initial user and display creds in the terminal
  first_username = "hm9k-#{SecureRandom.hex(5)}"
  first_password = SecureRandom.hex(16)

  user = User.create!(username: first_username, password: first_password)
  
  puts "###############################"
  puts "INITIAL LOGIN CREDENTIALS:"
  puts first_username
  puts first_password
  puts "###############################"
end

# setup default nmap configs
if ToolConfiguration.where(tool_name: "nmap").count == 0
  top_1000 = ToolConfiguration.create!(name: "top-1000", tool_name: "nmap")
  top_1000.tool_options << ToolOption.create!(name: "nmap-toggle-top-ports", value:"on")
  top_1000.tool_options << ToolOption.create!(name: "nmap-top-ports", value:"1000")
  top_1000.tool_options << ToolOption.create!(name: "nmap-toggle-port-range", value:"off")
  top_1000.tool_options << ToolOption.create!(name: "nmap-port-range", value:"")
  top_1000.tool_options << ToolOption.create!(name: "nmap-timing", value:"3")
  top_1000.tool_options << ToolOption.create!(name: "nmap-scripts", value:"")
  top_1000.tool_options << ToolOption.create!(name: "nmap-service-detection", value:"on")
  top_1000.tool_options << ToolOption.create!(name: "nmap-open-ports-only", value:"on")
  top_1000.tool_options << ToolOption.create!(name: "nmap-ping-unresponsive", value:"on")
  top_1000.tool_options << ToolOption.create!(name: "nmap-no-ports", value:"off")

  web_ports = ToolConfiguration.create!(name: "web-ports", tool_name: "nmap")
  web_ports.tool_options << ToolOption.create!(name: "nmap-toggle-top-ports", value:"off")
  web_ports.tool_options << ToolOption.create!(name: "nmap-top-ports", value:"")
  web_ports.tool_options << ToolOption.create!(name: "nmap-toggle-port-range", value:"on")
  web_ports.tool_options << ToolOption.create!(name: "nmap-port-range", value:"80,443,8080,3000,4567,8008")
  web_ports.tool_options << ToolOption.create!(name: "nmap-timing", value:"3")
  web_ports.tool_options << ToolOption.create!(name: "nmap-scripts", value:"")
  web_ports.tool_options << ToolOption.create!(name: "nmap-service-detection", value:"on")
  web_ports.tool_options << ToolOption.create!(name: "nmap-open-ports-only", value:"on")
  web_ports.tool_options << ToolOption.create!(name: "nmap-ping-unresponsive", value:"on")
  web_ports.tool_options << ToolOption.create!(name: "nmap-no-ports", value:"off")

  ping_sweep = ToolConfiguration.create!(name: "ping-sweep", tool_name: "nmap")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-toggle-top-ports", value:"off")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-top-ports", value:"")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-toggle-port-range", value:"off")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-port-range", value:"")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-timing", value:"4")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-scripts", value:"")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-service-detection", value:"off")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-open-ports-only", value:"off")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-ping-unresponsive", value:"on")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-no-ports", value:"on")

  ping_sweep = ToolConfiguration.create!(name: "vnc-sweep", tool_name: "nmap")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-toggle-top-ports", value:"off")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-top-ports", value:"")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-toggle-port-range", value:"yes")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-port-range", value:"5900")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-timing", value:"4")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-scripts", value:"")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-service-detection", value:"off")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-open-ports-only", value:"on")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-ping-unresponsive", value:"on")
  ping_sweep.tool_options << ToolOption.create!(name: "nmap-no-ports", value:"off")

  comprehensive = ToolConfiguration.create!(name: "comprehensive", tool_name: "nmap")
  comprehensive.tool_options << ToolOption.create!(name: "nmap-toggle-top-ports", value:"off")
  comprehensive.tool_options << ToolOption.create!(name: "nmap-top-ports", value:"")
  comprehensive.tool_options << ToolOption.create!(name: "nmap-toggle-port-range", value:"on")
  comprehensive.tool_options << ToolOption.create!(name: "nmap-port-range", value:"-")
  comprehensive.tool_options << ToolOption.create!(name: "nmap-timing", value:"3")
  comprehensive.tool_options << ToolOption.create!(name: "nmap-toggle-scripts", value:"on")
  comprehensive.tool_options << ToolOption.create!(name: "nmap-scripts", value:"default")
  # todo: maybe turn on OS stuff later if kali/root operation is standard 
  #comprehensive.tool_options << ToolOption.create!(name: "nmap-os-detection", value:"on")
  comprehensive.tool_options << ToolOption.create!(name: "nmap-service-detection", value:"on")
  comprehensive.tool_options << ToolOption.create!(name: "nmap-open-ports-only", value:"on")
  comprehensive.tool_options << ToolOption.create!(name: "nmap-ping-unresponsive", value:"on")
  comprehensive.tool_options << ToolOption.create!(name: "nmap-no-ports", value:"off")

  nahamsec = ToolConfiguration.create!(name: "nahamsec+", tool_name: "nmap")
  nahamsec.tool_options << ToolOption.create!(name: "nmap-toggle-top-ports", value:"off")
  nahamsec.tool_options << ToolOption.create!(name: "nmap-top-ports", value:"")
  nahamsec.tool_options << ToolOption.create!(name: "nmap-toggle-port-range", value:"on")
  nahamsec.tool_options << ToolOption.create!(name: "nmap-port-range", value:"3868,3366,8443,8080,9443,9091,3000,8000,5900,5901,5902,8081,6000,10000,8181,3306,5000,4000,8888,5432,15672,9999,161,4044,7077,4040,9000,8089,443,7447,7080,8880,8983,5673,7443")
  nahamsec.tool_options << ToolOption.create!(name: "nmap-timing", value:"3")
  nahamsec.tool_options << ToolOption.create!(name: "nmap-toggle-scripts", value:"off")
  nahamsec.tool_options << ToolOption.create!(name: "nmap-scripts", value:"")
  # todo: maybe turn on OS stuff later if kali/root operation is standard 
  #comprehensive.tool_options << ToolOption.create!(name: "nmap-os-detection", value:"on")
  nahamsec.tool_options << ToolOption.create!(name: "nmap-service-detection", value:"on")
  nahamsec.tool_options << ToolOption.create!(name: "nmap-open-ports-only", value:"on")
  nahamsec.tool_options << ToolOption.create!(name: "nmap-ping-unresponsive", value:"on")
  nahamsec.tool_options << ToolOption.create!(name: "nmap-no-ports", value:"off")
end


##if Project.all.size == 0
##  proj = Project.create!(name: "test project", uuid: SecureRandom.uuid.gsub!("-",""))
##  user.projects << proj
##end
