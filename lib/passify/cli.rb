require 'rubygems'
require 'thor'
require 'passify/version'

module Passify
  class CLI < Thor
    include Thor::Actions
    
    map '-h' => 'help'
    map '-v' => 'version'
    
    APACHE_CONF = '/etc/apache2/httpd.conf'
    VHOSTS_DIR = '/private/etc/apache2/passenger_pane_vhosts'

    desc "add", "Creates an application from the current working directory."
    def add(name = nil)
      check_for_passify
      error("This directory can not be served with passify. It has to be either a Rack application, a Rails 2.x application or a legacy (PHP/HTML) application.") unless is_valid_app?
      name = File.basename(pwd) if name.nil? || name.empty?
      name = urlify(name)
      host = "#{name}.local"
      if app_exists?(host)
        if is_same_app?(host, pwd)
          notice("This directory is already being served from http://#{host}. Run `passify open` to view it.")
        else
          exit if no?("A different app already exists under http://#{host}. Do you want to overwrite it?")
          sudome
          remove_app(host)
        end
      end
      
      silent_create_file ".passify", host
      sudome
      create_vhost(host, pwd)
      register_host(host)
      restart_apache
      say "The application was successfully set up and can be reached from http://#{host} . Run `passify open` to view it."
    end
    
    desc "remove", "Removes an existing link to the current working directory."
    def remove
      check_for_passify
      host = find_host
      
      sudome
      remove_app(host)
      say "The application was successfully removed."
    end
    
    desc "env", "Change the environment of the current app"
    def env(env = nil)
      check_for_passify
      notice("This application is a legacy application. The environment can not be changed.") if !is_rack_app? && !is_rails2_app?
      host = find_host
      
      line_no, rack_env = `grep -n 'RackEnv' #{vhost_file(host)}`.split(":")
      current_env = rack_env.strip.split(" ")[1]
      if env.nil? || env.empty?
        say "The application is running in '#{current_env}' environment."
      else
        notice("The application is already in '#{env}' environment.") if current_env == env
        sudome
        `sed -i '' '#{line_no}s!#{current_env}!#{env}!' #{vhost_file(host)}`
        restart_apache
        say "The application now runs in '#{env}' environment."
      end
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
      restart_apache
      FileUtils.mkdir_p(VHOSTS_DIR)
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
      check_for_passify
      Dir.foreach(VHOSTS_DIR) do |entry|
        if File.file?("#{VHOSTS_DIR}/#{entry}")
          host = entry[0..-12]
          say "  #{host} --> #{directory_for_host(host)}"
        end
      end
    end
    
    desc "open", "Opens the current working directory in browser."
    def open
      check_for_passify
      host = find_host
      
      system("open http://#{host}")
    end
    
    desc "version", "Shows the version"
    def version
       say "passify #{Passify::VERSION}"
    end
    
    private
      # http://jimeh.me/blog/2010/02/22/built-in-sudo-for-ruby-command-line-tools/      
      def sudome
        exec("#{sudo_command} passify #{ARGV.join(' ')}") if ENV["USER"] != "root"
      end
      
      def sudo_command
        rvm_installed? ? 'rvmsudo' : 'sudo'
      end

      def rvm_installed?
        system("which rvm > /dev/null 2>&1")
      end
      
      def check_for_passify
        error("Passify is currently not installed. Please run `passify install` first.") unless passify_installed?
      end
      
      def passify_installed?
        system("grep 'Include \\/private\\/etc\\/apache2\\/passenger_pane_vhosts\\/\\*\\.conf' #{APACHE_CONF} > /dev/null 2>&1")
      end
      
      def passenger_installed?
        system("grep 'PassengerRuby' #{APACHE_CONF} > /dev/null 2>&1")
      end
      
      def remove_app(host)
        app_dir = directory_for_host(host)
        remove_file(vhost_file(host), :verbose => false)
        unregister_host(host)
        remove_file("#{app_dir}/.passify", :verbose => false) if File.exists?("#{app_dir}/.passify")
      end
      
      def is_valid_app?
        if is_rack_app?
          FileUtils.mkdir_p('public')
          FileUtils.mkdir_p('tmp')
          true
        elsif is_rails2_app?
          true
        elsif is_legacy_app?
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
      
      def is_legacy_app?
        File.exists?('index.html') || File.exists?('index.php')
      end
      
      def find_host
        if File.exists?('.passify')
          host = File.open('.passify') {|f| f.readline}.strip
        else # support for passify 0.1.x
          name = File.basename(pwd)
          name = urlify(name)
          host = "#{name}.local"
        end
        notice("The current directory is not served via passify. Please run `passify add` first.") unless app_exists?(host)
        host
      end
      
      def app_exists?(host)
        File.exists?(vhost_file(host))
      end
      
      def is_same_app?(host, dir)
        directory_for_host(host) == dir
      end
      
      def directory_for_host(host)
        `grep 'DocumentRoot' #{vhost_file(host)}`.scan(/"([^"]*)"/).flatten[0][0..-8]
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
      
      def create_vhost(host, path)
        if is_legacy_app?
          create_legacy_vhost(host, path)
        else
          create_passenger_vhost(host, path)
        end
      end
      
      def create_passenger_vhost(host, path)
        silent_create_file vhost_file(host), <<-eos
<VirtualHost *:80>
  ServerName #{host}
  DocumentRoot "#{path}/public"
  RackEnv development
  <Directory "#{path}/public">
    Allow from all
    Options -MultiViews
  </Directory>
</VirtualHost>
          eos
      end
      
      def create_legacy_vhost(host, path)
        silent_create_file vhost_file(host), <<-eos
<VirtualHost *:80>
  ServerName #{host}
  DocumentRoot "#{path}"
  
  DirectoryIndex index.html index.php
  <Directory "#{path}">
    Allow from all
    AllowOverride All
  </Directory>  
  PassengerEnabled off
</VirtualHost>
          eos
      end
      
      def vhost_file(host)
        "#{VHOSTS_DIR}/#{host}.vhost.conf"
      end
      
      def register_host(host)
        system("/usr/bin/dscl localhost -create /Local/Default/Hosts/#{host} IPAddress 127.0.0.1 > /dev/null 2>&1")
      end
      
      def unregister_host(host)
        system("/usr/bin/dscl localhost -delete /Local/Default/Hosts/#{host} > /dev/null 2>&1")
      end
      
      def restart_apache
        system("apachectl graceful > /dev/null 2>&1")
      end
      
      def silent_create_file(path, content)
        create_file path, content, :verbose => false
      end
      
  end
end
