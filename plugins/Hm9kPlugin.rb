#https://joshrendek.com/2013/07/a-simple-ruby-plugin-system/
require 'set'

class Hm9kPlugin
  @plugins = Set.new

  def self.plugins
    @plugins
  end

  # maybe?
  #def self.get_host_plugins

  #end

  def self.register_plugins
    Object.constants.each do |klass|
      const = Kernel.const_get(klass)
      if const.respond_to?(:superclass) and const.superclass == Hm9kPlugin
        @plugins << const
      end
    end
  end
end