require 'json'
require 'pty'
require 'io/console'
require 'io/wait'
require 'em-websocket'

require './db.rb'
require './config.rb'

def run_command_detached(cmd, log = true)
  pid = Kernel.spawn({}, cmd)
  
  if log
    puts "executing command as a detached process: #{cmd}"
  end
  
  #Process.detach(pid)
end

# on launch, kill existing terminals we know of (clean relaunch)
pending_screen_kill = Terminal.all
pending_screen_kill.each do |t|
  run_command_detached("screen -xS #{t.tid} -X quit")
end

# on launch, delete all db references to existing terminals (clean relaunch)
Terminal.destroy_all

# requeue all jobs, too, i guess
Job.where(status: "running").each do |job|
  job.update_attributes!(status: "terminated")
end

Job.where(status: "queued").each do |job|
  job.update_attributes!(status: "terminated")
end

# the @terminals hash associates terminals with a user, as such:
=begin
@terminals = {1 => [Terminal, Terminal, Terminal]}
1 is a userid, Terminal is a ManagedTerminal instance

=end
@terminals = {}
@connected_users =  {}

class ManagedTerminal
  @initialized = false
  @hooked = false
  @background = "f" # sigh

  @uuid = nil
  @user = nil
  @tid = nil

  @stdout = nil
  @stdin = nil
  @pid = nil

  @is_screen = nil


  def initialize(tid, user, uuid, background)
    @tid = tid
    @user = user
    @uuid = uuid
    @background = background
  end

  def get_tid()
    return @tid
  end

  def spawn(cmd_line)
    @initialized = true
    @hooked = true
    @stdout, @stdin, @pid = PTY.spawn("/bin/bash", "-c", "cd hm9k-projects/#{@uuid}; exec #{cmd_line}")
    @is_screen = false
  end

  def spawn_screen()
    @initialized = true
    @hooked = false
    @is_screen = true
    #@stdout, @stdin, @pid = PTY.spawn("/bin/bash", "-c", "cd hm9k-projects/#{@uuid}; exec #{cmd_line}")
    run_command_detached("/usr/bin/screen -dmS #{@tid} /bin/bash")


    puts "spawned initial screen session in a PTY"
    sleep 0.2
    run_command_detached("/usr/bin/screen -xS #{@tid} -X stuff \"cd hm9k-projects/#{@uuid}^M\"")
  end

  def hook()
    if (@is_screen == false)
      @hooked = true
      return @stdout, @stdin
      # it's not a screen session, just hook to it
    end

    if (@initialized and !in_background?)
      puts "ATTACHING TO SCREEN VIA HOOK"
      @stdout, @stdin, @pid = PTY.spawn("/usr/bin/screen", "-xS", @tid)
      @hooked = true
      return @stdout, @stdin
    elsif (@initialized and in_background?)
      puts "ATTACHING TO BG SCREEN VIA HOOK"
      #@stdout, @stdin, @pid = PTY.spawn("/usr/bin/screen", "-xS", @tid)
      @hooked = true
      return @stdout, @stdin
    else
      puts "trying to attach to unitialized terminal"
      return nil, nil
    end
  end

  # this probably needs to *temporarily* close the stdin/stdout too... how?
  def unhook
    @hooked = false
  end

  def hooked?()
    @hooked
  end

  def close()
    @initialized = false
    @hooked = false
    @stdout.close
    @stdin.close
    Process.kill('QUIT', @pid)

    # must be removed from global array manually? can it remove itself??
  end

  def initialized?()
    @initialized
  end

  # handled in websocket handler atm
  def authenticated?()
    @authenticated
  end

  def resize(row, col)
    if @hooked
      @stdin.winsize = [row, col, 0, 0]
      if @is_screen
        run_command_detached("/usr/bin/screen -xS #{@tid} -X width #{col}", false)
        run_command_detached("/usr/bin/screen -xS #{@tid} -X height #{row}", false)
      end
    end
  end

  def write(data)
    @stdin.write data
  end

  def in_background?
    @background == "t"
  end

  def to_str
    "[Terminal:(initialized:#{initialized?},hooked?:#{hooked?},stdout:#{stdout})]"
  end
end


EM.run do
  puts "Terminal Server Started"

  EM::WebSocket.run(host: $terminal_server_bind_address, port: $terminal_server_bind_port) do |ws|
    channel = EM::Channel.new
    sid = channel.subscribe { |msg| ws.send_binary msg }

    authenticated = false
    user = nil
    project = nil
    scheduler_user = false
    terminals = []
    disconnected_tids = []

    ws.onopen do |handshake|
      sleep 0.5 # the client needs time to actually bind the terminal events.... sigh
    end

    ws.onclose do
      # get active terminals in this WS and unhook them all
      # 
      terminals.each do |t|
        t.unhook
      end

      puts "a connection has closed! unhooking all terminals!"

      #channel.unsubscribe(sid)
    end

    ws.onmessage do |msg|
      if (msg.starts_with?("s:"))
        if (authenticated)

          msg = msg[2..-1] # strip "s:"
          tid = msg.split(":")[0] # read new tid
          msg = msg[4..-1] # strip "tid:" from str
          msg = msg[29..-1] # strip the tid and : from the msg, leaving jsut the content
          tid = /\A[a-fA-F0-9]*\z/.match(tid)[0] # filter tid

          if (@terminals[tid])
            #puts "Writing to stdin of terminal #{tid}: #{msg}"
            @terminals[tid].write(msg)
          else
            puts "Attempt to write to invalid TID: #{msg.inspect}"
          end
        else
          # not authed, trying to send stdin??
          puts "unauthed request to stdin!!!"
        end
      else # go ahead and parse the json events from client
        msg = JSON.parse(msg)
        if (!authenticated) # wait for auth message to verify connection and setup user vars
          if msg["event"] == "auth"
            puts "authing..."
            if msg["data"]["terminal_token"] == $scheduler_secret # top secret code for scheduler websocket client auth
              puts "authing scheduler!"
              scheduler_user = true
              authenticated = true
            else # normal user auth
              user = User.where(session_key: msg["data"]["terminal_token"]).first

              if (!user)
                ws.send_binary "Authentication required."
                ws.close(1000)
              else

                project = Project.where(uuid: msg["data"]["uuid"]).first

                authenticated = true

                # mark this user as connected
                puts "Connected: #{user.username}"
                @connected_users[user.id.to_s] = [ws, channel]

                db_terminals = Terminal.where(user_id: user.id, project_id: project.id)
                
                terminal_list = []

                db_terminals.each do |t|
                  # check if we have the given db_terminal managed in the @terminals tracker hash
                  existing_term = @terminals[t.tid]

                  if (existing_term)
                    next if existing_term.in_background? # dont send background terminals to the user

                    stdout, stdin = existing_term.hook(); # setup io and hook terminal
                    terminal_list << {tid: t.tid}
                    
                  else
                    puts "uhh... there was a terminal in the database that isn't tracked by the terminal server."
                  end
                end # end for-each-terminal

                if (terminal_list.size > 0)
                  existing_terminals_event_data = {terminals: terminal_list}
                  ws.send('{"event": "existing_terminals", "data": '+existing_terminals_event_data.to_json + "}");
                end

              end # end successful user auth block
            end # end normal user auth
          end
        elsif scheduler_user #okay, we are authed as a scheduler here... handle schedule jobs
          if (msg["event"] == "run-tool")
            puts "running run-tool as scheduler!"
            user_id = msg["data"]["user_id"]
            project_id = msg["data"]["project_id"]
            job_id = msg["data"]["job_id"]

            db_job = Job.where(
              project_id: project_id,
              id: job_id, 
            ).first

            # we don't want to accidentally update the project and user variable from the scheduler perspective
            project_ = Project.find(project_id)
            user_ = User.find(user_id)

            ordinal = Terminal.where(user_id: user_.id).where(project_id: project_.id).count + 1

            # create the database object
            db_terminal = Terminal.create!(
              tid: SecureRandom.uuid.gsub!("-",""),
              user_id: user_.id,
              name: "#{ordinal}",
              project_id: project_.id,
              ordinal: ordinal
            )

            # spawn a new tool with tool defined from json data
            terminal = ManagedTerminal.new(db_terminal.tid, user_, project_.uuid, db_job.run_in_background)

            terminal.spawn(db_job.job_data); # setup io and spawn terminal... no screen
            db_job.tid = terminal.get_tid()
            db_job.save
            #terminal.spawn_screen(db_job.job_data)
            stdout, stdin = terminal.hook()

            puts "spawned terminal with cmd: #{db_job.job_data}"

            @terminals[db_terminal.tid] = terminal

            if db_job.run_in_background == "f" # if the run_in_bg flag is set, don't bother setting up any of this bs
              if (@connected_users[user_.id.to_s])
                ws_conn = @connected_users[user_.id.to_s][0] # the ws connection. to send json data
                binary_conn = @connected_users[user_.id.to_s][1] # the channel, to send binary (stdout) data
                # find the user who made the job, if they are connected
                if (!binary_conn.nil?)
                  read_stdout = proc do # read stdout always
                    sleep 1
                    while true
                      flag_dead = false
                      begin
                        data = stdout.read(1)
                        binary_conn.push "s:"+db_terminal.tid+":"+data
                      rescue Exception => ex# the clients can disconnect at any time. this also fires when a terminal is "finished"
                        puts "Couldn't send stdout! foreground job terminal dead"
                        puts "ex: #{ex.class} msg: #{ex.message}"
                        flag_dead = true
                      end
                      if (flag_dead)
                        db_job.update_attributes!(run_times: db_job.run_times + 1)

                        if (db_job.run_times >= db_job.max_runtimes)
                            if (db_job.max_runtimes == 0)
                              db_job.update_attributes!(status: "queued")
                            else
                              db_job.update_attributes!(status: "finished")
                            end
                        else
                          db_job.update_attributes!(status: "queued")
                        end
                        db_job.save!
                        puts "killing cmd: #{db_job.job_data} status of job:  #{db_job.status}"
                        db_job.save
                        if (@terminals[terminal.get_tid()])
                          @terminals[terminal.get_tid()].close()
                          @terminals[terminal.get_tid()] = nil
                          # tell the api server to update the db...? nah just do it here, users can't share terminals yet #todo
                          term = Terminal.where(tid: terminal.get_tid()).first
                          if (term)
                            term.delete
                          end
                        end

                        break
                      end
                    end
                  end
                  EventMachine.defer(read_stdout)

                  # deliver job-user a new_terminal event
                  puts "sending new job terminal out to user!"
                  tab_name = db_job.job_data.split(" ")[0]
                  if tab_name
                    tab_name = tab_name[0..15]
                  else
                    tab_name = ordinal.to_s
                  end
                  new_terminal_event_data = {
                    tid: db_terminal.tid
                  }
                  ws_conn.send('{"event": "new_terminal", "data": '+new_terminal_event_data.to_json + "}");
                else
                  puts "could not find connected user to term-serv with id: #{user_.id}. connected_users = #{@connected_users}"
                end
              end
            else # run_in_background is "true"
              read_stdout = proc do # read stdout always
                while true
                  flag_dead = false
                  begin
                    data = stdout.read(10) # we dont really need to even read it i guess
                  rescue Exception => ex# the clients can disconnect at any time. this also fires when a terminal is "finished"
                    puts "(bg) Couldn't send stdout! Background job terminal dead "
                    puts "ex (bg): #{ex.class} msg: #{ex.message}"
                    flag_dead = true
                    # do nothing!!
                  end
                  if (flag_dead)
                    db_job.update_attributes!(run_times: db_job.run_times + 1)

                    if (db_job.run_times >= db_job.max_runtimes)
                        if (db_job.max_runtimes == 0) # should run continually, requeue it
                          db_job.update_attributes!(status: "queued")
                        else # job is totally done and shouldn't run ever again
                          db_job.update_attributes!(status: "finished")
                        end
                    else
                      db_job.update_attributes!(status: "queued")
                    end
                    db_job.save!
                    puts "killing cmd: #{db_job.job_data} status of job:  #{db_job.status}"
                    db_job.save
                    if (@terminals[terminal.get_tid()])
                      @terminals[terminal.get_tid()].close()
                      @terminals[terminal.get_tid()] = nil
                      # tell the api server to update the db...? nah just do it here, users can't share terminals yet #todo
                      term = Terminal.where(tid: terminal.get_tid()).first
                      if (term)
                        term.delete
                      end
                    end

                    break
                  end
                end
              end
              EventMachine.defer(read_stdout)
              puts "RAN TERMINAL IN BG"
            end
          end
        else #okay, we are authed, handle regular authed JSON events here
          #puts "handling regular user events"
          if (msg["event"] == "disconnect_terminal")
            tid = msg["data"]["tid"]

            puts "disconnecting from a terminal. Signal all channels to die if they have this tid"
            db_terminal = Terminal.where(tid: tid).first

            if (!db_terminal)
              puts "That terminal doesn't exist! Doing nothing. "
              return
            end
            
            # check if we have the given db_terminal managed in the @terminals tracker hash
            existing_term = @terminals[db_terminal.tid]


            # the database matched what we have... good sign
            if (existing_term)
              next if existing_term.in_background? # dont send terminals in bg to user
              disconnected_tids << db_terminal.tid
              puts "Added to disconnect queue"
            else
              puts "[disconnect_terminal] Terminal exists in database but is not tracked by terminal server. Uh oh."
            end
          end

          if (msg["event"] == "connect_terminal")
            tid = msg["data"]["tid"]

            puts "connecting to existing terminal"
            db_terminal = Terminal.where(tid: tid).first

            if (!db_terminal)
              puts "That terminal doesn't exist! Doing nothing. "
              return
            end
            
            # check if we have the given db_terminal managed in the @terminals tracker hash
            existing_term = @terminals[db_terminal.tid]


            # the database matched what we have... good sign
            if (existing_term)
              next if existing_term.in_background? # dont send terminals in bg to user

              stdout, stdin = existing_term.hook(); # setup io and spawn terminal

              puts "sending terminal #{db_terminal.tid} from db!"
              new_terminal_event_data = {tid: db_terminal.tid, user: "", tabname: "#{db_terminal.ordinal}", ordinal: db_terminal.ordinal}
              ws.send('{"event": "connect_terminal", "data": '+new_terminal_event_data.to_json + "}");
              
              #
              read_stdout = proc do # read stdout always
                while true
                  flag_dead = false
                  flag_dc = false
                  begin
                    #puts "nread: #{stdout.nread}"
                    #sleep 1
                    nread = stdout.nread
                    if nread > 0
                      data = stdout.read(nread)
                    else
                      data = stdout.read(1)
                    end
                    #puts "data: #{data}"
                    #puts "-----"
                    channel.push "s:"+db_terminal.tid+":"+data
                    flag_dc = disconnected_tids.include? db_terminal.tid
                  rescue
                    flag_dead = true
                  end
                  if (flag_dead or flag_dc)
                    disconnected_tids.delete(db_terminal.tid)
                    puts "Disconnecting TID..."
                    puts "queue: #{disconnected_tids.inspect}"


                    #if (@terminals[db_terminal.tid])
                    #  @terminals[db_terminal.tid].close()
                    #  @terminals[db_terminal.tid] = nil
                    #  #`screen -XS #{tid} quit` we need this.. but it breaks shit
                    #  # tell the api server to update the db...? nah just do it here, users can't share terminals yet #todo
                    #  term = Terminal.where(tid: db_terminal.tid).first
                    #  if (term)
                    #    term.delete
                    #  end
                    #end

                    break
                  end
                end
              end
              EventMachine.defer(read_stdout)
            else
              puts "[connect_terminal] Terminal exists in database but is not tracked by terminal server. Uh oh."
            end
          end

          if (msg["event"] == "new_terminal")
            puts "delivering new terminal!!"
            # figure out this new terminals ordinal by counting existing terminals the user has
            ordinal = Terminal.where(user_id: user.id).where(project_id: project.id).count + 1

            # create the database object
            db_terminal = Terminal.create!(
              tid: SecureRandom.uuid.gsub!("-",""),
              user_id: user.id,
              name: "#{ordinal}",
              project_id: project.id,
              ordinal: ordinal
            )
              
            terminal = ManagedTerminal.new(db_terminal.tid, user, project.uuid, "f")

            terminal.spawn_screen(); # setup io and spawn terminal

            @terminals[db_terminal.tid] = terminal

            #puts "terminals hash: #{@terminals.inspect}"

            new_terminal_event_data = {tid: db_terminal.tid, user: "", tabname: "#{ordinal}", ordinal: ordinal}
            ws.send('{"event": "new_terminal", "data": '+new_terminal_event_data.to_json + "}");
          end

          if (msg["event"] == "close-terminal")
            puts "closing terminal!"
            tid = msg["data"]["tid"]
            # todo: make sure the user owns the tid, even though it's hard to guess
            if (@terminals[tid])
              @terminals[tid].close()
              @terminals[tid] = nil
              puts "CLOSING SCREEN"
              run_command_detached("screen -xS #{tid} -X quit")

              #5.times do |a|
              #res = `screen -XS #{tid} quit`
              #puts "WHAT: #{res}"
              #end
              # todo: update job that it's done if this was a terminal from a job

              db_job = Job.where(tid: tid).first
              if db_job
                db_job.update_attributes!(status: "terminated")
              end


              # tell the api server to update the db...? nah just do it here, users can't share terminals yet #todo
              term = Terminal.where(tid: tid).first
              if (term)
                term.delete
              end
            end
          end

          if (msg["event"] == "resize")
            tid = msg["data"]["tid"]
            row = msg["data"]["row"]
            col = msg["data"]["col"]
            #puts "resize tid: #{tid}"

            t = @terminals[tid]
            if (t)
              t.resize(row, col)
            end
          end
        end # end authed json parsing

      end # end parsing json events
    end # end ws.onmessage
  end
end