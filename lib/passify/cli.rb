require 'rubygems'
require 'thor'

module Passify
  class CLI < Thor
    include Thor::Actions
    
    HOSTS_FILE = '/etc/hosts'
    APACHE_CONF = '/etc/apache2/httpd.conf'

    desc "link", "Creates an application from the current working directory."
    def link(name = nil)
      error("Passify is currently not installed. Please run `passify install` first.") unless passify_installed?
      error("This directory can not be served with Passenger. Please create a `config.ru`-file.") unless is_valid_app?
      name = File.basename(pwd) if name.nil? || name.empty?
      name = urlify(name)
      url = "#{name}.local"
      if app_exists?(url)
        if is_same_app?(url, pwd)
          notice("This directory is already being served from http://#{url}. Run `passify open #{name}` to view it.")
        else
          exit if no?("A different app already exists with under http://#{url}. Do you want to overwrite it?")
          unlink(name)
        end
      end
      
      sudome
      app_config = <<-eos
  # passify: Begin -- #{url}
    <VirtualHost *:80>
      ServerName #{url}
      DocumentRoot "#{pwd}/public"
      RackEnv development
      <Directory "#{pwd}/public">
        Allow from all
        Options -MultiViews
      </Directory>
    </VirtualHost>
  # passify: End -- #{url}
        eos
      insert_into_file APACHE_CONF, app_config, :after => "  # passify: Begin application configuration\n"
      append_to_file HOSTS_FILE, "\n127.0.0.1 #{url}" unless has_hosts_entry?(url)
      system("apachectl graceful > /dev/null 2>&1")
      say "The application was successfully set up and can be reached from http://#{url} . Run `passify open #{name}` to view it."
    end
    
    desc "unlink", "Removes an existing link to the current working directory."
    def unlink(name = nil)
      error("Passify is currently not installed. Please run `passify install` first.") unless passify_installed?
      name = File.basename(pwd) if name.nil? || name.empty?
      name = urlify(name)
      url = "#{name}.local"
      notice("No application exists under http://#{url} .") unless app_exists?(url)
      sudome
      system("sed -i '' '#{find_begin(url)},#{find_end(url)}d' #{APACHE_CONF}")
    end
    
    desc "install", "Installs passify into the local Apache installation."
    def install
      error("Passenger seems not to be installed. Refer to http://www.modrails.com/ for installation instructions.") unless passenger_installed?
      notice("passify is already installed.") if passify_installed?
      sudome
      append_to_file APACHE_CONF, <<-eos
\n\n# passify: Begin configuration
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
    
    desc "uninstall", "Uninstalls passify"
    def uninstall
      notice("passify is not installed.") unless passify_installed?
      sudome
      system("sed -i '' '#{find_line('passify: Begin configuration')},#{find_line('passify: End configuration')}d' #{APACHE_CONF}")
      say "The uninstallation of passify is complete."
    end
    
    desc "restart", "Restart the current application"
    def restart
      notice("The current directory does not seem to be a rack application.") unless is_rack_app?
      FileUtils.mkdir_p('tmp')
      system "touch tmp/restart.txt"
    end
    
    desc "list", "Lists all applications served with passify."
    def list
      error("Passify is currently not installed. Please run `passify install` first.") unless passify_installed?
      apps = `grep 'passify: Begin --' #{APACHE_CONF}`.split("\n")
      apps.each do |app|
        url = app.match(/-- (.+)$/)[0][3..-1]
        say "  #{url} --> #{directory_for_url(url)}"
      end
    end
    
    desc "open", "Opens the current working directory in browser."
    def open(name = nil)
      error("Passify is currently not installed. Please run `passify install` first.") unless passify_installed?
      name = File.basename(pwd) if name.nil? || name.empty?
      name = urlify(name)
      url = "#{name}.local"
      system("open http://#{url}")
    end
    
    desc "version", "Shows the version"
    def version
       say "passify #{Passify::VERSION}"
    end
    
    private
      # http://jimeh.me/blog/2010/02/22/built-in-sudo-for-ruby-command-line-tools/      
      def sudome
        exec("#{sudo_command} #{ENV['_']} #{ARGV.join(' ')}") if ENV["USER"] != "root"
      end
      
      def passify_installed?
        system("grep 'passify: Begin configuration' #{APACHE_CONF} > /dev/null 2>&1")
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
      
      def is_valid_app?
        if is_rack_app?
          true
        elsif is_rails2_app? || is_radiant_app?
          say "This appears to be a Rails 2.x application. You need a `config.ru`-file."
          if(yes? "Do you want to autogenerate a basic `config.ru`-file?")
            create_file 'config.ru', "require File.dirname(__FILE__) + '/config/environment'\nrun ActionController::Dispatcher.new"
            true
          else
            false
          end
        else
          false
        end
      end
      
      def is_rack_app?
        File.exists?('config.ru')
      end
      
      def is_rails2_app?
        system("grep 'RAILS_GEM_VERSION' config/environment.rb > /dev/null 2>&1")
      end
      
      def is_radiant_app?
        system("grep 'Radiant::Initializer' config/environment.rb > /dev/null 2>&1")
      end
      
      def app_exists?(url)
        system("grep 'passify: Begin -- #{url}' #{APACHE_CONF} > /dev/null 2>&1")
      end
      
      def is_same_app?(url, dir)
        directory_for_url(url) == dir
      end
      
      def directory_for_url(url)
        `grep -A 3 'passify: Begin -- #{url}' #{APACHE_CONF}`.split("\n").last.match(/\".+\"/)[0][1..-9]
      end
      
      def has_hosts_entry?(url)
        system("grep '#{url}' #{HOSTS_FILE} > /dev/null 2>&1")
      end
      
      def find_begin(url)
        find_line("passify: Begin -- #{url}")
      end
      
      def find_end(url)
        find_line("passify: End -- #{url}")
      end
      
      def find_line(pattern)
        `grep -n '#{pattern}' #{APACHE_CONF}`.split(":").first
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
      
      def notice(message)
        say message, :yellow
        exit
      end
      
  end
end
