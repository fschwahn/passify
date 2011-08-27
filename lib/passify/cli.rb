require 'rubygems'
require 'thor'
require 'passify/version'

module Passify
  class CLI < Thor
    include Thor::Actions
    
    HOSTS_FILE = '/etc/hosts'
    APACHE_CONF = '/etc/apache2/httpd.conf'
    VHOSTS_DIR = '/private/etc/apache2/passenger_pane_vhosts'

    desc "add", "Creates an application from the current working directory."
    def add(name = nil)
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
          remove(name)
        end
      end
      
      sudome
      create_vhost(url, pwd)
      append_to_file HOSTS_FILE, "\n127.0.0.1 #{url}" unless has_hosts_entry?(url)
      system("apachectl graceful > /dev/null 2>&1")
      say "The application was successfully set up and can be reached from http://#{url} . Run `passify open #{name}` to view it."
    end
    
    desc "remove", "Removes an existing link to the current working directory."
    def remove(name = nil)
      error("Passify is currently not installed. Please run `passify install` first.") unless passify_installed?
      name = File.basename(pwd) if name.nil? || name.empty?
      name = urlify(name)
      url = "#{name}.local"
      notice("No application exists under http://#{url} .") unless app_exists?(url)
      sudome
      remove_file(vhost_file(url))
      system("sed -i '' '#{get_hosts_line(url)}d' #{HOSTS_FILE}") if has_hosts_entry?(url)
    end
    
    desc "install", "Installs passify into the local Apache installation."
    def install
      error("Passenger seems not to be installed. Refer to http://www.modrails.com/ for installation instructions.") unless passenger_installed?
      notice("passify is already installed.") if passify_installed?
      sudome
      append_to_file APACHE_CONF, <<-eos
\n\n# Added by the Passenger preference pane
# Make sure to include the Passenger configuration (the LoadModule,
# PassengerRoot, and PassengerRuby directives) before this section.
<IfModule passenger_module>
  NameVirtualHost *:80
  <VirtualHost *:80>
    ServerName _default_
  </VirtualHost>
  Include /private/etc/apache2/passenger_pane_vhosts/*.conf
</IfModule>
        eos
      system("apachectl graceful > /dev/null 2>&1")
      say "The installation of passify is complete."
    end
    
    desc "uninstall", "Uninstalls passify"
    def uninstall
      notice("passify is not installed.") unless passify_installed?
      sudome
      first_config_line = find_line_in_conf('# Added by the Passenger preference pane').to_i
      system("sed -i '' '#{first_config_line},#{first_config_line+9}d' #{APACHE_CONF}")
      say "The uninstallation of passify is complete. The vhosts in `#{VHOSTS_DIR}` have not been deleted."
    end
    
    desc "restart", "Restart the current application"
    def restart
      notice("The current directory does not seem to be a passenger application.") unless is_valid_app?
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
      
      def sudo_command
        rvm_installed? ? 'rvmsudo' : 'sudo'
      end

      def rvm_installed?
        system("which rvm > /dev/null 2>&1")
      end
      
      def passify_installed?
        system("grep 'Include \\/private\\/etc\\/apache2\\/passenger_pane_vhosts\\/\\*\\.conf' #{APACHE_CONF} > /dev/null 2>&1")
      end
      
      def passenger_installed?
        system("grep 'PassengerRuby' #{APACHE_CONF} > /dev/null 2>&1")
      end
      
      def is_valid_app?
        if is_rack_app? || is_rails2_app?
          true
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
      
      def app_exists?(url)
        File.exists?(vhost_file(url))
      end
      
      def is_same_app?(url, dir)
        directory_for_url(url) == dir
      end
      
      def directory_for_url(url)
        `grep 'DocumentRoot' #{vhost_file(url)}`.scan(/"([^"]*)"/).flatten[0][0..-8]
      end
      
      def has_hosts_entry?(url)
        !!get_hosts_line(url)
      end
      
      def get_hosts_line(url)
        `grep -n '#{url}' #{HOSTS_FILE}`.split(":").first
      end
      
      def find_line_in_conf(pattern)
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
      
      def create_vhost(url, path)
        create_file vhost_file(url), <<-eos
<VirtualHost *:80>
  ServerName #{url}
  DocumentRoot "#{path}/public"
  RackEnv development
  <Directory "#{path}/public">
    Allow from all
    Options -MultiViews
  </Directory>
</VirtualHost>
          eos
      end
      
      def vhost_file(url)
        "#{VHOSTS_DIR}/#{url}.vhost.conf"
      end
      
  end
end
