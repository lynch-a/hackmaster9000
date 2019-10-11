require 'msfrpc-client'

user = 'user'
pass = 'pass'

opts = {
  host: '127.0.0.1',
  port: 55553,
  uri:  '/api/',
  ssl:  true
}
rpc = Msf::RPC::Client.new(opts)
rpc.login(user, pass)

puts rpc.call('core.version')