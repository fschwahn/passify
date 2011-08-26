require 'rubygems'
require 'thor'

module Passify
  class CLI < Thor
    include Thor::Actions
    
    HOSTS_FILE = '/etc/hosts'
    APACHE_CONF = '/etc/apache2/httpd.conf'
    # APACHE_CONF = '/Users/fabian/test.conf'
    
    
    desc "link", "Creates an application from the current working directory"
    def link(name = nil)
      name = pwd if name.nil? || name.empty?
      
    end
    
    desc "install", "Installs passify into the local Apache installation"
    def install
      error("Passenger seems not to be installed. Refer to http://www.modrails.com/ for installation instructions.") unless passenger_installed?
      error("passify is already installed") if passify_installed?
      sudome
      append_to_file APACHE_CONF, <<-eos


# passify: Begin configuration
# Do not alter any of the following comments as they are used by passify to find the right lines.
<IfModule passenger_module>
  NameVirtualHost *:80
  <VirtualHost *:80>
    ServerName _default_
  </VirtualHost>
# passify: Begin application configuration
</IfModule>
# passify: End configuration
        eos
    end
    
    private
      # http://jimeh.me/blog/2010/02/22/built-in-sudo-for-ruby-command-line-tools/
      def sudome
        exec("sudo #{ENV['_']} #{ARGV.join(' ')}") if ENV["USER"] != "root"
      end
      
      def passify_installed?
        system("grep '# passify: Begin configuration' #{APACHE_CONF} > /dev/null 2>&1")
      end
      
      def passenger_installed?
        system("grep 'PassengerRuby' #{APACHE_CONF} > /dev/null 2>&1")
      end
      
      def pwd
        urlify(File.basename(Dir.pwd))
      end

      def urlify(name)
        name.downcase.gsub(/[\s\_]/, '-').gsub(/[^a-z\d\-]/, '').gsub(/\-+/, '-')
      end
      
      def error(message)
        say message, :red
        exit(false)
      end
      
  end
end
