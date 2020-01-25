require 'sinatra/base'
require 'json'
require 'uri'
require 'socket'
require 'resolv'
require 'csv'
require 'pry'
require 'resque'
require 'whenever'
require './db.rb'
require './config.rb'
require 'rake'
require 'action_view'
require 'action_view/helpers'
require 'securerandom'



include ActionView::Helpers::DateHelper

class Hackmaster < Sinatra::Base
  set :bind, $webserver_bind_to_address # bind to internet!
  set :port, $webserver_port
  set :environment, $webserver_environment
  set :server, "thin"
  set :sessions, true
  set :session_secret, SecureRandom.hex(256)
  
  include ERB::Util


  register do
    def auth (type)
      condition do
        redirect "/login" unless send("is_#{type}?")
      end
    end
  end

  helpers do
    def is_user?
      @user != nil
    end
  end

  before do
    if session[:uid].blank?
      @user = nil
    else
      @user = User.find(session[:uid])
    end
  end

  get "/login" do
    session[:uid] = nil
    erb :login
  end

  get "/projects", :auth => :user do
    @projects = @user.projects
    @all_projects = Project.all

    erb :projects
  end

  post "/projects/new", :auth => :user do
      proj = Project.create!(name: params[:project_name], uuid: SecureRandom.uuid.gsub!("-",""))
      @user.projects << proj
      Dir.mkdir("hm9k-projects/#{proj.uuid}/")
      Dir.mkdir("hm9k-projects/#{proj.uuid}/scans")
      Dir.mkdir("hm9k-projects/#{proj.uuid}/scans/parsed")

      scanloader_job = {project: proj.uuid}
      Job.create!(
        user_id: @user.id,
        project_id: proj.id,
        job_type: "SCANLOADER",
        job_data: scanloader_job.to_json,
        run_every: 10,
        run_times: 0,
        status: "queued",
        run_in_background: true, # this doesn't affect scanloader jobs
        paused: false
      )
      return true;
  end

  post "/login" do
    @user = User.where(username: params[:username]).first
    
    if (@user and params[:password])
      if (@user.password == params[:password])
        session[:uid] = @user.id
        @user.session_key = SecureRandom.uuid.gsub!("-","");
        @user.save
        session.options[:expire_after] = 21600
        redirect "/projects"
      else
        session[:uid] = nil
        redirect "/login"
      end
    else
      session[:uid] = nil
      redirect "/login"
    end
  end
  

  get "/logout" do
    session[:uid] = nil
    redirect "/login"
  end

  get "/" do
    redirect "/projects"
  end

  get "/tool_configurations/:tool_config_id", auth: :user do
    #@project = Project.find(params[:project_id])

    tool_configuration = ToolConfiguration.find(params[:tool_config_id])
    options = tool_configuration.tool_options
    
    content_type :text
    options.to_json(except: :id)
  end

  get "/projects/:project_id/jobs", auth: :user do
    @project = Project.find(params[:project_id])
    @jobs = Job.where(project_id: @project.id)

    erb :jobs
  end

  get "/projects/:project_id/jobs/:job_id", auth: :user do
    @project = Project.find(params[:project_id])
    @job = Job.where(project_id: @project.id, id: params[:job_id]).first

    erb :'partials/_job', layout: false, locals: {job: @job}
  end

  get "/projects/:project_id/applications/:application_id/pages", auth: :user do
    @project = Project.find(params[:project_id])

    @application = WebApplication.where(project_id: @project, id: params[:application_id]).first

    erb :'partials/_page_summary', layout: false, locals: {application: @application}
  end

  get "/projects/:project_id/applications/:application_id/pages/:page_id", auth: :user do
    @project = Project.find(params[:project_id])

    @application = WebApplication.where(project_id: @project, id: params[:application_id]).first

    @page = Page.where(application_id: @application.id, id: params[:page_id]).first

    erb :'partials/_page', layout: false, locals: {page: @page}
  end

  get '/projects/:id', auth: :user do
    @user = User.find(session[:uid])

    @project = Project.find(params[:id])
    @jobs = Job.where(project_id: @project.id).order(id: :desc)
    
    # no bueno sorting
    @web_applications = WebApplication.where(project_id: @project.id, hidden: false).order(id: :desc)

    @triggers = Trigger.where(project_id: @project.id)

    @terminals = Terminal.where(user_id: @user.id, project_id: @project.id) # fix this relation (todo)

    # if the current user doesn't already have access to this project...
    if (!@user.projects.where(id: @project.id).first)
      # ... then give them access anyways
      @user.projects << @project
      @user.save
    end
    #todo: check if user can access project
    # ??? @user.projects << proj


    erb :project
  end

  get '/clear', auth: :user do
    Host.delete_all
    FeedItem.delete_all
    Service.delete_all
    
    WebApplication.delete_all
    Page.delete_all
    Input.delete_all
    Header.delete_all

    Job.where(job_type: "TOOL").delete_all
    db_job = Job.where(job_type: "SCANLOADER").first
    db_job.status = "finished"
    db_job.save

    #ToolConfiguration.delete_all
    #ToolConfigurationsOptions.delete_all
    #ToolOption.delete_all

    Trigger.delete_all
    TriggerCondition.delete_all

    HostScript.delete_all
    ServiceScript.delete_all

    Terminal.delete_all
    ProjectsTerminals.delete_all
    TerminalsUsers.delete_all

    DnsRecord.delete_all
    DirsearchScan.delete_all
    DirsearchResult.delete_all
    "true"
  end

  ###### HOSTS BELOW
  post '/projects/:project_id/hosts', auth: :user do
    @user = User.find(session[:uid])
    @project = @user.projects.where(id: params[:project_id]).first

    #begin
      draw = params[:draw]
      start = params[:start]
      length = params[:length]
      search = params[:search][:value]
      if(length == "-1")
        length = 999999
      end

      if @project
        @all_hosts_in_project = Host.where(project_id: @project.id)

        total_count = @all_hosts_in_project.count

        # we will filter down this list of all hosts by searching
        @hosts = @all_hosts_in_project

        search_filter_regexes = {
          id_filter_regex: {regex: /id:(\d+)/, search_field: :id},
          hidden_filter_regex: {regex: /hidden:(true|false)/, search_field: :hidden},
          risk_filter_regex: {regex: /risk:(0|1|2|3)/, search_field: :risk}
        }

        ### BUG - searching also shows hidden stuff
        if (search.length > 1)
          # sigh
          search_filter_regexes.each do |filter_name, filter|
            if search[filter[:regex]] != nil
              @hosts = @hosts.where(filter[:search_field] => search[filter[:regex]].split(":")[1])
              search.gsub!(filter[:regex], "").strip! # remove this filter from the str
            end            
          end

          # search with the rest of the str by ip
          @hosts = @hosts.where(["ip LIKE ?", "%#{search}%"])
        else
          @hosts = Host.where(project_id: @project.id, hidden: false)
        end

        count_before_pagination = @hosts.count 
        # do ordering
        @hosts = @hosts.offset(start).limit(length).order(id: :desc)


        if @hosts
          data = []

          @hosts.each do |host|
            html = File.open('views/partials/_host_row.erb').read
            template = ERB.new(
              html
            )
            b = binding
            b.local_variable_set(:host, host)
            data << {card: template.result(b)}
          end

          data_table_response = {
            draw: draw,
            recordsTotal: total_count,
            recordsFiltered: count_before_pagination,
            data: data
          }


          content_type :json
          return data_table_response.to_json
        end
      else # no project
        content_type :json
        return "{}"
      end
    #rescue Exception => ex
    #  puts "bad search query: #{search}"
    #  puts ex.message
    #  ex.backtrace
    #  content_type :json
    #  return "{}"
    #end
  end

  # render a host datatable row
  get '/projects/:project_id/hosts/:id', auth: :user do
    @user = User.find(session[:uid])
    @project = @user.projects.where(id: params[:project_id]).first

    if @project
      @host = Host.find(params[:id])
      @dns_records = DnsRecord.where(project_id: @host.project.id)

      erb :'partials/_host_row', layout: false, :locals => { dns_records: @dns_records, host: @host }
    end
  end

    # render services
  get '/projects/:project_id/hosts/:host_id/services', auth: :user do
    @user = User.find(session[:uid])
    @project = @user.projects.where(id: params[:project_id]).first

    #todo: access control // does this user have access to this host?
    @host = Host.find(params[:host_id])

    erb :'partials/_service_table', layout: false, :locals => { host: @host }
  end

  ###### DOMAINS BELOW
  # server-side processing for domain datatable
  post '/projects/:project_id/domains', auth: :user do
    @user = User.find(session[:uid])
    @project = @user.projects.where(id: params[:project_id]).first

    #begin
      draw = params[:draw]
      start = params[:start]
      length = params[:length]
      if(length == "-1")
        length = 999999
      end

      search = params[:search][:value]

      if @project
        @all_domains_in_project = Domain.where(project_id: @project.id)

        total_count = @all_domains_in_project.count

        @filtered_domains = @all_domains_in_project

        search_filter_regexes = {
          id_filter_regex: {regex: /id:(\d+)/, search_field: :id},
          hidden_filter_regex: {regex: /hidden:(true|false)/, search_field: :hidden},
          risk_filter_regex: {regex: /risk:(0|1|2|3)/, search_field: :risk},
        }

        if (search.length > 1)
          # sigh
          search_filter_regexes.each do |filter_name, filter|
            if search[filter[:regex]] != nil
              @filtered_domains = @filtered_domains.where(filter[:search_field] => search[filter[:regex]].split(":")[1])
              search.gsub!(filter[:regex], "").strip! # remove this filter from the str
            end            
          end

          @filtered_domains = @filtered_domains.where(["domain_name LIKE ?", "%#{search}%"])
        else
          @filtered_domains = Domain.where(project_id: @project.id, hidden: false, tld: true)
        end
        
        count_before_pagination = @filtered_domains.count

        # do ordering
        @filtered_domains = @filtered_domains.offset(start).limit(length).order(id: :desc)

        if @filtered_domains
          data = []

          @filtered_domains.each do |domain|
            html = File.open('views/partials/_domain_row.erb').read
            template = ERB.new(
              html
            )
            b = binding
            b.local_variable_set(:domain, domain)
            data << {card: template.result(b)}
          end

          data_table_response = {
            draw: draw,
            recordsTotal: total_count,
            recordsFiltered: count_before_pagination,
            data: data
          }


          content_type :json
          return data_table_response.to_json
        end
      else # no project
        content_type :json
        return "{}"
      end
    #rescue
    #  puts "bad search query: #{search}"
    #  content_type :json
    #  return "{}"
    #end
  end

  ###### DNS RECORDS BELOW
  # server-side processing for domain datatable
  post '/projects/:project_id/dns_records', auth: :user do
    @user = User.find(session[:uid])
    @project = @user.projects.where(id: params[:project_id]).first

    #begin
      draw = params[:draw]
      start = params[:start]
      length = params[:length]
      if(length == "-1")
        length = 999999
      end

      search = params[:search][:value]

      if @project
        @all_dns_records_in_project = DnsRecord.where(project_id: @project.id)

        total_count = @all_dns_records_in_project.count

        @filtered_dns_records = @all_dns_records_in_project

        search_filter_regexes = {
          id_filter_regex: {regex: /id:(\d+)/, search_field: :id},
          hidden_filter_regex: {regex: /hidden:(true|false)/, search_field: :hidden},
          risk_filter_regex: {regex: /risk:(0|1|2|3)/, search_field: :risk},
          type_filter_regex: {regex: /type:(A|AAAA|NS|MX|SOA)/, search_field: :record_type}
        }

        if (search.length > 1)
          # sigh
          search_filter_regexes.each do |filter_name, filter|
            if search[filter[:regex]] != nil
              @filtered_domains = @filtered_domains.where(filter[:search_field] => search[filter[:regex]].split(":")[1])
              search.gsub!(filter[:regex], "").strip! # remove this filter from the str
            end            
          end

          @filtered_domains = @filtered_domains.where(["record_key LIKE ?", "%#{search}%"])
        else
          @filtered_domains = DnsRecord.where(project_id: @project.id, hidden: false)
        end
        
        count_before_pagination = @filtered_domains.count

        # do ordering
        @filtered_domains = @filtered_domains.offset(start).limit(length).order(id: :desc)

        if @filtered_domains
          data = []

          @filtered_domains.each do |dns_record|
            html = File.open('views/partials/_domain_row.erb').read
            template = ERB.new(
              html
            )
            b = binding
            b.local_variable_set(:dns_record, dns_record)
            data << {card: template.result(b)}
          end

          data_table_response = {
            draw: draw,
            recordsTotal: total_count,
            recordsFiltered: count_before_pagination,
            data: data
          }


          content_type :json
          return data_table_response.to_json
        end
      else # no project
        content_type :json
        return "{}"
      end
    #rescue
    #  puts "bad search query: #{search}"
    #  content_type :json
    #  return "{}"
    #end
  end

  # render a domain datatable row
  get '/projects/:project_id/domains/:dns_record_id', auth: :user do
    @user = User.find(session[:uid])
    @project = @user.projects.where(id: params[:project_id]).first

    if @project
      @dns_record = DnsRecord.where(project_id:@project.id, id: params[:dns_record_id]).first
      
      if @dns_record
        if @dns_record.record_key != ""
          erb :'partials/_domain_row', layout: false, locals: { dns_record: @dns_record }
        end
      else
        puts "cannot render dns record: #{params[:dns_record_id]}, it doesn't exist"
      end
    end
  end

  ###### WEB APPS BELOW
  #server-side processing of web apps
  post '/projects/:project_id/web_applications', auth: :user do
    @user = User.find(session[:uid])
    @project = @user.projects.where(id: params[:project_id]).first

    #begin
      draw = params[:draw]
      start = params[:start]
      length = params[:length]
      if(length == "-1")
        length = 999999
      end

      search = params[:search][:value]

      if @project
        @all_web_applications_in_project = WebApplication.where(project_id: @project.id)

        total_count = @all_web_applications_in_project.count

        # we will filter down this list of all webapps by searching
        @web_applications = @all_web_applications_in_project

        search_filter_regexes = {
          id_filter_regex: {regex: /id:(\d+)/, search_field: :id},
          scheme_filter_regex: {regex: /scheme:(https?)/, search_field: :scheme},
          hidden_filter_regex: {regex: /hidden:(true|false)/, search_field: :hidden},
          port_filter_regex: {regex: /port:(\d+)/, search_field: :port},
          risk_filter_regex: {regex: /risk:(0|1|2|3)/, search_field: :risk}
        }

        if (search.length > 1)
          # sigh
          search_filter_regexes.each do |filter_name, filter|
            if search[filter[:regex]] != nil
              @web_applications = @web_applications.where(filter[:search_field] => search[filter[:regex]].split(":")[1])
              search.gsub!(filter[:regex], "").strip! # remove this filter from the str
              puts "remaining search str: #{search}"
            end            
          end

          # search with the rest of the str by name
          @web_applications = @web_applications.joins(:domain)
          .where(["domain_name LIKE ?", "%#{search}%"])
        else
          @web_applications = WebApplication.where(project_id: @project.id, hidden: false)
        end
        count_before_pagination = @web_applications.count
        # do ordering
        @web_applications = @web_applications.offset(start).limit(length).order(id: :desc)

        if @web_applications
          data = []

          @web_applications.each do |web_application|
            html = File.open('views/partials/_web_application_row.erb').read
            template = ERB.new(
              html
            )
            b = binding
            b.local_variable_set(:web_application, web_application)
            data << {card: template.result(b)}
          end

          data_table_response = {
            draw: draw,
            recordsTotal: total_count,
            recordsFiltered: count_before_pagination,
            data: data
          }


          content_type :json
          return data_table_response.to_json
        end
      else # no project
        content_type :json
        return "{}"
      end
    #rescue
    #  puts "bad search query: #{search}"
    #  content_type :json
    #  return "{}"
    #end
  end

  # render a web application datatable row
  get '/projects/:project_id/web_applications/:web_application_id', auth: :user do
    @user = User.find(session[:uid])
    @project = @user.projects.where(id: params[:project_id]).first

    if @project
      @web_application = WebApplication.where(project_id: @project.id, id: params[:web_application_id]).first

      erb :'partials/_web_application_row', layout: false, locals: { web_application: @web_application }
    end
  end


  ###### JOBS BELOW
  # server-side processing of jobs
  post '/projects/:project_id/jobs', auth: :user do
    @user = User.find(session[:uid])
    @project = @user.projects.where(id: params[:project_id]).first

    #begin
      draw = params[:draw]
      start = params[:start]
      length = params[:length]
      if(length == "-1")
        length = 999999
      end

      search = params[:search][:value]

      if @project
        @all_jobs_in_project = Job.where(project_id: @project.id)

        total_count = @all_jobs_in_project.count

        # we will filter down this list of all hosts by searching
        @jobs = @all_jobs_in_project

        search_filter_regexes = {
         status_filter_regex: {regex: /status:(running|finished|queued+)/i, search_field: :status}
        }

        if (search.length > 1)
         # sigh
         search_filter_regexes.each do |filter_name, filter|
           if search[filter[:regex]] != nil
             @jobs = @jobs.where(filter[:search_field] => search[filter[:regex]].split(":")[1].downcase)
             search.gsub!(filter[:regex], "").strip! # remove this filter from the str
           end            
         end

         # search with the rest of the str by ip
         @jobs = @jobs.where(["job_data LIKE ?", "%#{search}%"])
        else
         @jobs = Job.where(project_id: @project.id)
        end

        count_before_pagination = @jobs.count 

        @jobs = @jobs.offset(start).limit(length).order(id: :desc)

        if @jobs
          data = []

          @jobs.each do |job|
            html = File.open('views/partials/_job_row.erb').read
            template = ERB.new(
              html
            )
            b = binding
            b.local_variable_set(:job, job)
            data << {card: template.result(b)}
          end

          data_table_response = {
            draw: draw,
            recordsTotal: total_count,
            recordsFiltered: count_before_pagination,
            data: data
          }


          content_type :json
          return data_table_response.to_json
        end
      else # no project
        content_type :json
        return "{}"
      end
    #rescue
    #  puts "bad search query: #{search}"
    #  content_type :json
    #  return "{}"
    #end
  end

  # render a job datatable row
  get '/projects/:project_id/web_applications/:job_id', auth: :user do
    @user = User.find(session[:uid])
    @project = @user.projects.where(id: params[:project_id]).first

    if @project
      @job = Job.where(project_id: @project.id, id: params[:job_id]).first

      erb :'partials/_job_row', layout: false, locals: { job: @job }
    end
  end

  ###### TRIGGERS BELOW
  # render a trigger data table row
  get '/projects/:project_id/triggers/:id', auth: :user do
    @user = User.find(session[:uid])
    @project = @user.projects.where(id: params[:project_id]).first

    if @project
      @trigger = Trigger.where(id: params[:id], project_id: @project.id).first

      erb :'partials/_trigger_row', layout: false, :locals => { trigger: @trigger }
    end
  end


  ###### TERMINAL PROVIDER
  get '/request_terminal/:tid', auth: :user do
    @terminal = Terminal.where(tid: params[:tid]).first

    if !@terminal
      return "what u doin"
    end
    # check if the terminal exists in the database
    # possibly do access control idk lol
    # return a partial containing the terminal to be loaded into the page

    erb :'partials/_terminal', layout: false, locals: { tid: @terminal.tid }
  end

  get '/request_terminal_tab/:tid', auth: :user do
    @terminal = Terminal.where(tid: params[:tid]).first

    if !@terminal
      return "what u doin"
    end
    # check if the terminal exists in the database
    # possibly do access control idk lol
    # return a partial containing the terminal to be loaded into the page

    erb :'partials/_terminal_tab', layout: false, locals: { tid: @terminal.tid, ordinal: @terminal.ordinal }
  end
end

Hackmaster.run!
