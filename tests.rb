# test the ingesters

# load the plugins
require './plugins/Hm9kPlugin.rb'
Dir["./plugins/*/plugin.rb"].each { |f| require f }
Hm9kPlugin.register_plugins

# does this work?
Dir.glob("ingesters/*.rb").each do |file|
  puts "Including ingester: #{file}"
  require_relative file
end

# test the plugins
Hm9kPlugin.plugins.each do |plugin|
  puts "Running plugin: #{plugin.name}"

  files_to_parse = Dir["test_files/"+plugin.file_filter].map{|filename| filename}
  puts "File filter detected these files for plugin to parse: #{files_to_parse}"

  files_to_parse.each do |file|
    plugin.parse(1, file)
    puts "File parsed: #{File.basename(file)}"
  end
end