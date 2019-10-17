hack faster with hackmaster9000
==

A framework to help run terminal based tools and visualizing/using the resulting data. It's unique because the web UI provides you a real server-side terminal. It's also collaborative with real-time updates to all users, for the most part.

It primarily helps with some recon tasks at the moment (subdomain scanning / nmap / taking screenshots / dirsearch / etc). It will be improved in the future to make it useful for other things!



What it looks like
==
![image](https://i.imgur.com/vDUNsDy.png)

![image](https://i.imgur.com/T2h038b.png)

![image](https://i.imgur.com/lQY9uvt.png)

![image](https://i.imgur.com/QnJIqX5.png)

![image](https://i.imgur.com/YcwEA8g.png)


Get it running
==

Docker
==


Kali Linux (2019.2)
==
```

#### General kali VM stuff (skippable if you're already setup)

# My freshly-downloaded VM of Kali came without repos in the sources.lst, so:
echo "deb http://http.kali.org/kali kali-rolling main non-free contrib" >> /etc/apt/sources.lst
echo "deb-src http://http.kali.org/kali kali-rolling main non-free contrib" >> /etc/apt/sources.lst

apt-get update

#vmware tools, if used
apt-get install -y open-vm-tools-desktop fuse


#### Setup dependencies, install tools, install hm9k, setup directories, etc

# dependencies
apt-get install -y nodejs postgresql postgresql-contrib libpq-dev imagemagick phantomjs ruby ruby-dev libgmp-dev build-essential libsqlite3-dev openjdk-8-jdk patch zlib1g-dev liblzma-dev


# install hm9k
cd /usr/share/
git clone https://github.com/lynch-a/hackmaster9000
cd hackmaster9000
gem install bundler:2.0.1
bundle install

# install dnscan
cd /usr/share
git clone https://github.com/dbsec/dnscan.git
cd dnscan
pip install -r requirements.txt
sudo ln -s /usr/share/dnscan/dnscan.py /usr/bin/dnscan

# install dirsearch
cd /usr/share
git clone https://github.com/maurosoria/dirsearch.git
sudo ln -s /usr/share/dirsearch/dirsearch.py /usr/bin/dirsearch

# install gitgot
cd /usr/share
git clone https://github.com/BishopFox/GitGot.git
sudo ln -s /usr/share/GitGot/gitgot.py /usr/bin/gitgot

# install sslscan
sudo apt-get install sslscan

# install some node dependencies for the screenshot utility - you might need to "npm init" in the custom_tools dir first
cd /usr/share/hackmaster9000/custom_tools
npm install puppeteer why-is-node-running generic-pool

# setup symlinks for some of the custom tools
sudo ln -s /usr/share/hackmaster9000/custom_tools/xtreme-scraper.rb /usr/bin/xtreme-scraper
chmod +x /usr/bin/xtreme-scraper

sudo ln -s /usr/share/hackmaster9000/custom_tools/web-screenshot.rb /usr/bin/web-screenshot
chmod +x /usr/bin/web-screenshot

sudo ln -s /usr/share/hackmaster9000/custom_tools/check_vnc.rb /usr/bin/check_vnc
chmod +x /usr/bin/check_vnc

sudo ln -s /usr/share/hackmaster9000/custom_tools/pwnVNC.py /usr/bin/pwnVNC
chmod +x /usr/bin/pwnVNC

# this is a meme tool with no web interface, but if you've read this far you might as well try it out lol. It takes a wordlist and uses a recurrent neural network to attempt to brute force other subdomains based on it. No, it's not very good.
sudo ln -s /usr/share/hackmaster9000/custom_tools/rnnsub.py /usr/bin/rnnsub
chmod +x /usr/bin/rnnsub

sudo ln -s /usr/share/hackmaster9000/custom_tools/zdns /usr/bin/zdns
chmod +x /usr/bin/zdns

sudo ln -s /usr/share/hackmaster9000/custom_tools/metaldetector /usr/bin/metaldetector
chmod +x /usr/bin/metaldetector

# install zmap
sudo apt-get install -y zmap

# install some general use wordlists
cd /usr/share/wordlists

git clone https://github.com/fuzzdb-project/fuzzdb.git

curl https://raw.githubusercontent.com/assetnote/commonspeak2-wordlists/master/subdomains/subdomains.txt -o commonspeak2-free.txt

curl https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/shubs-stackoverflow.txt -o shubs-stackoverflow.txt

curl https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/dns-Jhaddix.txt -o jhaddix-subdomains.txt

curl https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Common-Credentials/best15.txt -o best15.txt

# kali should already come with this
#curl https://raw.githubusercontent.com/danielmiessler/SecLists/c196a6e62d0b63d6be0c84e6fa224352ea5949df/Passwords/Leaked-Databases/rockyou.txt.tar.gz -o rockyou.txt.tar.gz

# unzip rockyou, it's nice to have around
gzip -d rockyou.txt.gz

mkdir /usr/share/wordlists/subdomains

# copy some of the dnscan subdomains to the kali wordlist folder - they're nice too!
cp /usr/share/dirsearch/db/dicc.txt /usr/share/wordlists/dirsearch-default.txt
cp /usr/share/dnscan/subdomains-*.txt /usr/share/wordlists/subdomains/

cd /usr/share/hackmaster9000
service postgresql start

echo "You will now be switched to the postgre system user to setup the database. You should:"
echo "Type \password<enter>"
echo "Then follow the instructions to change the password to something secure "
echo "Then:
echo "CREATE DATABASE hm9k;"
echo "\connect hm9k"
echo "CREATE EXTENSION pg_trgm;" # i don't remember if this is actually necessary... but it works! so i'm not changing it right now!
echo "\q"

sudo -u postgres psql postgres

echo "Now that postgre is configured, edit config.rb to include the database password and/or change other configuration details"
```

That's it for installation! I recommend running it by following this process:
```
# run this to enter a screen session named "hm9k"
screen -S hm9k

# start the main.rb web server - the first-run credentials will be output to the console
cd ~/git/hackmaster9000/
ruby main.rb

ctrl+a c # type this on your keyboard to create a new screen session

# now follow the same for the below
cd ~/git/hackmaster9000/
ruby terminal-server.rb

ctrl+a c


cd ~/git/hackmaster9000/
ruby api-server.rb

ctrl+a c


cd ~/git/hackmaster9000/
java -jar HackJob.jar
```

And if you log back in to a server running hm9k and wish to get back into the screen session:
```
screen -r hm9k
```

But all you really need to do is run the 4 services above however you want.

Then login at:

```
http://localhost:8080
Login with your credentials as output by main.rb the first time you run it
```


Helpful Information
==
* The scanloader isn't very good at parsing big data. Especially tons of domains from one file. For example, if you `dnscan` a domain with wildcards enabled and a big wordlist. You can tell what's going on by killing HackJob and running the scanloader yourself:

`ruby ScanLoader.rb <the_project_uuid>`

For example, given a project folder like hm9k-projects/d8a1d790e6164d9a9ce2d79d63219e87 if you open a terminal in the web UI, the UUID that should be passed to the scanloader is d8a1d790e6164d9a9ce2d79d63219e87

This way you'll at least get output from the scanloader, and it usually gets the job done eventually if the auto-parsing isn't working. It also sometimes completely locks up my development VM ¯\\_(ツ)_/¯. You can then rerun HackJob and all should work as normal.

* There's no way to add or manage users. Mess with the database yourself:

```you@server:hackmaster9000$ irb
irb(main):001:0> require './db.rb'
=> true
irb(main):002:0> User
=> User(id: integer, username: string, password_hash: string, session_key: string, session_expires: datetime, email: string)
irb(main):003:0> User.create!(username: "YourUsername", password: "SomeSecurePassword")
=> true
```

You can use `irb` with `require './db.rb'` to accomplish whatever you want with the database.


Component Description
==
OUTDATED BUT STILL INFORMATIONALLY RELEVANT

`main.rb`
* Sinatra webserver that handles basic business logic, authentication, and access to the frontend. Renders partials.

`db.rb`
* This is a comprehensive activerecord database definition included by all services, including seed data.

`terminal-server.rb`
* A websocket server that accepts connections from the frontend. This websocket requires authentication, and a single websocket connection controls all terminal elements on the page. This server handles all communication between the frontend, terminals, and terminal related things such as jobs. The scheduler service (see HackJob below) maintains one internal connection to the terminal server and sends it special commands to spawn jobs. This means that the terminal server needs to be run BEFORE HackJob. HackJob will not hard-fail if it can't connect, it will just stop working.
* Handles:
  * User Requests (Users send these messages)
    * `auth` - authenticate the websocket, check the database if this user+project already has any terminals, and if so, send them the existing terminals
    * `new_terminal` - spawns a new PTY and returns it to the client who requested it
    * `close-terminal` - closes a terminal by TID
    * `resize` - handle PTY resize message
    * `stdout` (custom) - non-JSON message to transmit stdout
   * Scheduler Requests (the scheduler sends these messages)
     * `run-tool` - given a userid, projectid, and a raw command line string, will spawn a tool running the cmd line string and send the resulting terminal back to the user (in scheduler terms, a TOOL job)

`api-server.rb`
* A websocket server that accepts a connection from the frontend and the scanloader service. This server receives database updates, processes the database update, then pushes the result to all of the connected frontend clients that have also authenticated to the project.
* Handles:
  * User Requests:
    * `auth` - auth and set the project for the connection as either scanloader or user
    * `set-host-risk` - users click a new host risk button in the frontend, this button updates the database with the new risk and sends the event to all other users looking at the project
    * `add-job` - create a custom Job for the scheduler, schedule it, then tell everyone else about the new job
  * Requests From Scanloader (scanloader sends us these messages)
    * `add-host` - create a host in the database, and broadcast the host to all users connected to the project that made the host
    * `add-service` - create a service in the database, and broadcast the service to all users connected to the project that made the service

`ScanLoader.rb`
* A websocket CLIENT that parses the files in a given project UUID and updates the database. When it's done running, it notifies the api server to tell clients that they should reload data visible in the frontend.
* Sends jobs:
  * `add-host` - when nmap parses a scan and finds a host, it will tell the `api-server` to make a host
  * `add-service` - when nmap parses a scan and finds a service running on a host, it will tell the `api-server` to make a service

`HackJob`
* A scheduling server written in Java that connects to the database and polls for jobs from the `jobs` table. When a job is found to be ready to run, the scheduler will "fire" the job, which has two possibilities: (1) run the `scanloader`, to trigger a scan of project files, or (2) send a message to the `terminal-server`, to run a new tool/scan/whatever.




I have a terminal based tool and would like to incorporate it into hackmaster9000. How do I do that?
==

It's easy! you MUST:
* Extend ScanLoader to include a parser for the tool output (difficulty ranges from super easy for simple data to kinda hard for complicated data)

you COULD ALSO EASILY:
* Create a frontend UI for it
* Write some JS to run the command - required if you create a web UI for it

you MIGHT WANT TO:
* Make changes to the code, as sort of described below, so it can trigger other jobs to happen based on specific rules
* Change frontend code to include the tool in the dropdown list for "send to"

Example process for adding a tool, including frontend UI and JS:

First, find this part in ScanLoader.rb, it's near the bottom:

```
scan_these = {
  "nmap": {
    "parser_function": :load_nmap_scan, 
    "file_list": find_project_files_basename("nmap-*.xml")
  },
  "dirsearch": {
    "parser_function": :load_dirsearch_scan,
    "file_list": find_project_files_basename("dirsearch-*.json")
  },
  "dnscan": {
    "parser_function": :load_dnscan,
    "file_list": find_project_files_basename("dnscan-*.txt")
  },
  "crtsh": {
    "parser_function": :load_crtsh_scan,
    "file_list": find_project_files_basename("crtsh-*.json")
  },
  "raw domain": {
    "parser_function": :load_raw_domains,
    "file_list": find_project_files_basename("raw-domains-*.txt")
  }
}
```

Here, you add your own output file format that will be parsed when scans are loaded. Like so:

```
"raw domain": {
  "parser_function": :load_raw_domains,
  "file_list": find_project_files_basename("raw-domains-*.txt")
},
"pwnvnc": {
  "parser_function": :load_pwnvnc,
  "file_list": find_project_files_basename("pwnvnc-*.txt")
}
```

In this example case, we are adding a tool called "pwnvnc". `:load_pwnvnc` is a symbol reference to a new ruby function you are about to write. The `:file_list` key will point to an array of files filtered down by the regex string you write to detect files that your parser function should operate on. In this case, files like "pwnvnc-something.txt" will be sent to :load_pwnvnc for parsing. Your parse function will be responsible for ingesting the data in the file it's designed to parse. 

Now create a method matching your `parser_function` key in the `scan_these` hash. In this case `def load_pwnvnc(file) ... end` is added to ScanLoader.rb. Your parser function can be as simple or as complicated as you like. Very simple parser functions can be written for tools that accomplish one task and return one kind of result. For example, the `pwnVNC` tool targets one IP and one port and outputs an IP and port ONLY IF a valid VNC server with unauthenticated access is detected. It does not output a file when no VNC server is found. The parser for it, `load_pwnvnc` is very simple, here it is fully commented, it can be found in ScanLoader.rb. Further below you can see it w/o comments if you don't need the extra explanation.

```
def load_pwnvnc(file)
  # First, load the full path to the scanfile. ScanLoader.rb executes
  # from the hackmaster9000/ folder itself.
  # The scanloader knows what project it's loading, so this will load 
  # the extended path to the exact scan file.
  file_contents = File.read("hm9k-projects/"+@project.uuid+"/"+file)

  # An output file for pwnvnc is very simple, if the given IP and port to the tool are found
  # to have an unauth VNC server running, it will output the IP and port it was discovered on.
  # A scan file looks like this:

  # name: pwnvnc-anything.txt
  # contents (not including the dashes):
  #-------------
  # 127.0.0.1 5900
  # \EOF
  #

  # So we have to ingest an IP and a port.
  # An IP is best associated with a "host", so we will use the ingest_host(ip) function provided by the scanloader.
  # A port is best associated as a "service", so we will use the ingest_service(...) function

  # Read each output line of the file individually
  file_contents.each_line do |line|
    next if (line.length <  2) # remove garbage lines
    line.strip! # remove any extra whitespaces around the current parsed line
    split = line.split(" ") # split the line by the single whitespace we know is between the IP and port

    ip = split[0] # variable to hold the parsed ip as a string
    port = split[1] # variable to hold the parsed port as a string

    # Now that we have parsed the output file line, we have the information we need to
    # create the database items.
    # ingest_*() methods will do all the heavy lifting of committing real database
    # updates (scan data).
     
    # The ingest_host() function takes one argument, the string IP address
    # and returns an ActiveRecord database record of which:
    # 1) If the ip address already exists in the database, nothing is 
    #    triggered and the existing row is returned.
    # 2) If the ip address has never seen before, a new one is created, triggers
    #    are launched, and the new row is returned.
    # 3) If the given ip address does not match an IP address regex,
    #    it is assumed to be a domain, and is ingested as a dns record instead and returns nil (TODO)

    db_host = ingest_host(ip)

    #(TODO): It's hard to handle dealing with potentially returning domains here, so we ignore them
    if (db_host) # todo: if ingest_host returns nil, it means it was given a domain. it created the domain instead and won't return the id so we can't update a domain in the ui
      # If we are in this if statement, it means the db_host was created (or already existed)
      # and therefore the IP address from the output file has been parsed.
      # But we still must ingest a service.
      # Ingesting a service will first check if a service exists.
      # If the service exists:
      #  1) Update the service with the information provided in the arguments
      #  2) Return the service (no triggers)
      # If the service is new:
      # 1) Create the service with the specified parameters,
      # 2) Run any triggers
      # 3) Return the service

      db_service = ingest_service(db_host.id, port, "Unauthenticated VNC - vncPWN", "", "", "")

      # We also need to update the host feed that something was found It goes into a <pre>
      # This feed update will refresh the host in the client after it's written
      
      feed_str = "pwnVNC discovered VNC service on port: #{db_service.port_number} has unauth access. SS: /ss/vnc-#{db_host.ip}-#{db_service.port_number}.jpg"
      
      update_feed(db_host, "pwnVNC", feed_str, true)

    end
    # TODO: figure out how to update the domain if it was added this way?
  end
  # we are done parsing the scan file, so move it to the parsed scans folder where it won't be parsed again
  FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
end
```

* Note: the nmap parsing function can be used as a reference if you wish to implement a more complicated parser, though it uses the Nmap::Parser ruby library so it's not too bad.

And without comments, if you just need the reference:

```
def load_pwnvnc(file)
  file_contents.each_line do |line|
    next if (line.length <  2) 
    line.strip! 

    split = line.split(" ") 
    ip = split[0] 
    port = split[1]

    db_host = ingest_host(ip)

    if (db_host)
      db_service = ingest_service(db_host.id, port, "Unauthenticated VNC - vncPWN", "", "", "")
      
      feed_str = "pwnVNC discovered VNC service on port: #{db_service.port_number} has unauth access. SS: /ss/vnc-#{db_host.ip}-#{db_service.port_number}.jpg"
      
      update_feed(db_host, "pwnVNC", feed_str, true)
    end
  end
  FileUtils.move("hm9k-projects/"+@project.uuid+"/"+file, "hm9k-projects/"+@project.uuid+"/scans/parsed/"+file)
end
```

If you need to ingest more complicated data that doesn't fit within the db schema, you have to update the db schema and write an ingest_whatever() method yourself. Plenty of examples in there.

If you want to support triggers on your custom data, it is frontent heavy and we won't do it here but there are plenty of examples in the source. (triggers.erb) - you have to write annoying frontend UI to create the triggers in the database, but in the scanloader it is fairly easy to deal with (ctrl+f checkTrigger)

At this point, we could run pwnVNC manually from the terminal or place our own pwnvnc-*.txt output files in the project directory and they would be parsed and updated in the ui. All we needed to do was write the parser to ingest the data. You could create a trigger here that runs pwnVNC every time a service is discovered and everyone looking at the project will be updated when VNC is found and can explore it further. It would Just Work(tm)

But we probably also want to write a frontend to facilitate running pwnVNC from the web interface. You need to create  a _your_tool_name.erb in `views/tools` that will template out all the inputs to the tool. Most command line inputs can be broken into a few categories, but they're all just string inputs that we have to fill in with the UI. I have included a number of convenience methods that make writing the tool tab UI very easy for common field inputs. For example:

```
<%= erb :'tools/tool_helpers/_text_input', locals: {
          tool_name: tool_name,
          label: "Target",
          field_name: "target",
          field_value: "",
          placeholder: "127.0.0.1"
        }
%>
```

Combined with some boilerplate boostrap rows and cols and a few other helpers, we have a functioning tool-launcher UI. Here is pwnVNC in its entirety:

https://github.com/lynch-a/hackmaster9000/blob/master/views/tools/_pwn_vnc.erb

That's all, just 2 named inputs, some help text, and a runner erb. You must also modify `tools.erb` to include your tool as a tab on the tools page

Now you write some JS to slap the command into a real terminal command by including an addition like this in `hm9k.js`:

```
function generate_pwn_vnc_command() {
  var cmd = "pwnVNC";

  var target = $("#pwn-vnc-target").val();
  if (target != "") {
    cmd += " "+ target;
  }

  var port = $("#pwn-vnc-port").val();
  if (port != "") {
      cmd += " " + port;
  }

  return cmd;
}

$("#pwn-vnc-run").click(function() {
  var cmd = generate_pwn_vnc_command();
  schedule_or_run("pwn-vnc", cmd);
});
```

That is the simple version of getting pwn-vnc to run when the run button is clicked. All of the input names are defined in the erb automatically. We can also use JS to extend functionality, check out this addition:

```
function generate_pwn_vnc_command() {
  var cmd = "pwnVNC";

  var target = $("#pwn-vnc-target").val();
  if (target != "") {
    cmd += " "+ target;
  }

  var port = $("#pwn-vnc-port").val();
  if (port != "") {
      cmd += " " + port;
  }

  return cmd;
}

$("#pwn-vnc-run").click(function() {
  
  //// hooooolll up'
  // before pwn-vnc is run, we want so support multiple targets
  // we save and split the target list by " "
  // for each target, we set the target box and call schedule_or_run to kick off each command individually
  var target = $("#pwn-vnc-target").val();

  var targets = target.split(" ");
  if (targets.length > 1) {
    for(var i = 0; i < targets.length; i++) {
      $("#pwn-vnc-target").val(targets[i]);
      if ($("#pwn-vnc-target").val().length > 1) { // ignore empty target problems
        var cmd = generate_pwn_vnc_command();
        schedule_or_run("pwn-vnc", cmd);
      }
    }
  } else {
    var cmd = generate_pwn_vnc_command();
    schedule_or_run("pwn-vnc", cmd);
  }
});
```

This example allows you to put multiple host IP's into the pwnvnc input box and run the tool against all of those IP's as a batch set of jobs.

So you:
* Extended scanloader to include a tool
* Created a frontend UI for it
* Wrote some JS to run the command

And now it's there forever, ready to be used as you please either as a trigger or against specific selected targets.


Other Stuff
==
tested on:
* ruby 2.4.1
* ruby 2.5.1
* screenshot2.js custom tool runs with node 10+


You can edit the following line in your .bashrc (it's line #46 in my .bashrc) to force color if it's not working out of the box:
```
#force_color_prompt=yes
Change to:

force_color_prompt=yes
```
