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
      error("Passify is currently not installed. Please run `passify install` first.") unless passify_installed?
      sudome
      name = urlify(File.basename(pwd)) if name.nil? || name.empty?
      url = "#{name}.local"
      app_config = <<-eos
  # passify: Begin #{url}
    <VirtualHost *:80>
      ServerName suedseetraum.local
      DocumentRoot "#{pwd}"
      RackEnv development
      <Directory "#{pwd}/public">
        Order allow,deny
        Allow from all
      </Directory>
    </VirtualHost>
  # passify: End #{url}
        eos
        insert_into_file APACHE_CONF, app_config, :after => "  # passify: Begin application configuration\n"
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
      system("apachectl graceful > /dev/null 2>&1")
      say "The installation of passify is complete."
    end
    
    private
      # http://jimeh.me/blog/2010/02/22/built-in-sudo-for-ruby-command-line-tools/      
      def sudome
        exec("#{sudo_command} #{ENV['_']} #{ARGV.join(' ')}") if ENV["USER"] != "root"
      end
      
      def passify_installed?
        system("grep '# passify: Begin configuration' #{APACHE_CONF} > /dev/null 2>&1")
      end
      
      def passenger_installed?
        system("grep 'PassengerRuby' #{APACHE_CONF} > /dev/null 2>&1")
      end
      
      def sudo_command
        rvm_installed? ? 'rvmsudo' : 'sudo'
      end

      def rvm_installed?
        system("which rvm > /dev/null 2>&1")
      end
      
      def pwd
        @pwd ||= Dir.pwd
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
