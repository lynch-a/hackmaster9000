require 'securerandom'

# webserver (main.rb)
$webserver_bind_to_address = '127.0.0.1' # set to 0.0.0.0 to access from the internet
$webserver_port = 8080
$webserver_environment = :development # or :production to turn off errors and stuff

# terminal server (terminal-server.rb)
$terminal_server_bind_address = '127.0.0.1' # set to 0.0.0.0 to access from the internet
$terminal_server_bind_port = 8081

# api server (api-server.rb)
$api_server_bind_address = '127.0.0.1' # set to 0.0.0.0 to access from the internet
$api_server_bind_port = 8082

# database config
$database_host = 'localhost'
$database_username = 'hm9k'
# change this to whatever you set the postgre pw to in initial setup
$database_password = 'test101'

# write this database password in a file for hackjob to read
File.open('db_password.txt', 'w') {|f| f.write($database_password) }


# does the hackjob secret key exist yet?
if !File.file?('hackjob_secret.txt')
  # If not, make a secure one on first run
  File.open('hackjob_secret.txt', 'w') {|f| f.write(SecureRandom.hex(20)) }
end

$scheduler_secret = File.read('hackjob_secret.txt')