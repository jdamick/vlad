require 'vlad'

namespace :vlad do
  ##
  # Glassfish app server

  set :glassfish_address,       "127.0.0.1"
  set :glassfish_command,       'glassfish'
  set :glassfish_environment,   "production"
  set :glassfish_port,          8000
  set :glassfish_contextroot,   '/'
  set :glassfish_pid_file,      'tmp/pids/glassfish.pid'
  set :glassfish_runtimes,      2
  set :glassfish_runtimes_min,  1
  set :glassfish_runtimes_max,  10
  set :glassfish_log_level,     3
  
  # -c, --contextroot PATH: change the context root (default: '/')
  # 
  # -p, --port PORT:        change server port (default: 3000)
  # 
  # -e, --environment ENV:  change rails environment (default: development)
  # 
  # -n --runtimes NUMBER:   Number of JRuby runtimes to create initially
  # 
  # --runtimes-min NUMBER:  Minimum JRuby runtimes to create
  # 
  # --runtimes-max NUMBER:  Maximum number of JRuby runtimes to create
  # 
  # -d, --daemon:           Run GlassFish as daemon. Currently works with
  #                         Linux and Solaris OS.
  # 
  # -P, --pid FILE:         PID file where PID will be written. Applicable
  #                         when used with -d option. The default pid file
  #                         is tmp/pids/glassfish-<PID>.pid
  # 
  # -l, --log FILE:         Log file, where the server log messages will go.
  #                         By default the server logs go to
  #                         log/glassfish.log file.
  #
  # --log-level LEVEL:      Log level 0 to 7. 0:OFF, 1:SEVERE, 2:WARNING,
  #                         3:INFO (default), 4:FINE, 5:FINER, 6:FINEST,
  #                         7:ALL.
  # 
  # --config FILE:          Configuration file location. Use glassfish.yml
  #                         as template. Generate it using 'gfrake config'
  #                         command.
  
  def glassfish_start_cmd
    cmd = [
            "cd #{current_path} &&", 
            "#{glassfish_command}",
            "-e #{glassfish_environment}",
            "-p #{glassfish_port}",
            "-c #{glassfish_contextroot}",
            ("-P #{current_path}/#{glassfish_pid_file}" if glassfish_pid_file),
            "-d", # needs to be after --pid for some reason glassfish only likes it that way..
            "-n #{glassfish_runtimes}",
            "--runtimes-min #{glassfish_runtimes_min}",
            "--runtimes-max #{glassfish_runtimes_max}",
            "--log-level #{glassfish_log_level}"
          ].compact.join ' '
  end
  
  desc "Start the app servers"
  remote_task :start_app, :roles => :app do
    run glassfish_start_cmd
  end

  desc "Stop the app servers"
  remote_task :stop_app, :roles => :app do
    cmd = "cat #{current_path}/#{glassfish_pid_file} | xargs -i kill {}"
    puts "$ #{cmd}"
    run cmd
  end
  
  desc "Stop, then restart the app servers"
  remote_task :restart_app, :roles => :app do
    Rake::Task['vlad:stop_app'].invoke
    Rake::Task['vlad:start_app'].invoke
  end
  
  desc "Install init.d script for app server"
  remote_task :install_initd, :roles => :app do
    erb_obj = Object.new
    # Support templating of member data.
    erb_obj.instance_eval { def get_binding; binding; end }
    erb_obj.instance_eval %Q(def glassfish_start_cmd; "#{glassfish_start_cmd}"; end)
    
    erb_initd = ERB.new(IO.read(File.join(File.dirname(__FILE__), 'glassfish_initd.erb')))
    glassfish_initd = erb_initd.result(erb_obj.get_binding)
    
    temp = Tempfile.new(application)
    temp << glassfish_initd
    temp.close
    
    rsync(temp.path, "/tmp/#{application}_initd")
    sudo "mv /tmp/#{application}_initd /etc/init.d/#{application}"
    sudo "chown root:root /etc/init.d/#{application}"
    sudo "chmod 755 /etc/init.d/#{application}"
    sudo "/sbin/chkconfig --add #{application}"
    sudo "/sbin/chkconfig #{application} on"
    File.delete(temp.path)
  end
  
  remote_task :cleanup_glassfish_tmp do 
    max = keep_releases
    if releases.length > max 
      directories = (releases - releases.last(max)).map { |release|
        "#{File.join(releases_path, release)}/tmp/.glassfish"
      }.join(" ")

      sudo "rm -rf #{directories}"
    end
  end
  task :cleanup => :cleanup_glassfish_tmp
end
