$:.unshift(File.expand_path('./lib'))
require 'puma/capistrano'

set :application, "graphiti"
set :deploy_to, "./graphiti"
# set :deploy_via, :remote_cache
# set :scm, :git
# set :repository, "git@github.com:paperlesspost/graphiti.git"
# set :user, "paperless"
# set :use_sudo, false
# set :normalize_asset_timestamps, false

namespace :deploy do
  task :start, :roles => :app, :except => { :no_release => true } do
    run "bundle exec puma -t 1:16 -b tcp://0.0.0.0:81"
	# run "bundle exec puma -q -d -t 1:16 -b tcp://0.0.0.0:81"
  end
  task :stop, :roles => :app, :except => { :no_release => true } do
    # run "kill `cat #{unicorn_pid}`"
  end
  task :graceful_stop, :roles => :app, :except => { :no_release => true } do
    # run "kill -s QUIT `cat #{unicorn_pid}`"
  end
  task :reload, :roles => :app, :except => { :no_release => true } do
    # run "kill -s USR2 `cat #{unicorn_pid}`"
  end
  task :restart, :roles => :app, :except => { :no_release => true } do
    stop
    start
  end
end

task :production do
  server 'graphiti.pp.local', :web, :app, :db, :primary => true
end

namespace :graphiti do
  task :link_configs do
    # run "cd #{release_path} && ln -nfs #{shared_path}/config/settings.yml #{release_path}/config/settings.yml"
    # run "cd #{release_path} && ln -nfs #{shared_path}/config/amazon_s3.yml #{release_path}/config/amazon_s3.yml"
  end

  task :compress do
    run "java -jar wro4j-runner-1.4.5-jar-with-dependencies.jar -m"
  end
end

namespace :bundler do
  desc "Automatically installed your bundled gems if a Gemfile exists"
  task :install_gems, :roles => :web do
	run "bundle install --without test development --deployment"
    # run %{if [ -f #{release_path}/Gemfile ]; then cd #{release_path} &&
     # mkdir -p #{release_path}/vendor &&
      # ln -nfs #{shared_path}/vendor/bundle #{release_path}/vendor/bundle &&
      # bundle install --without test development --deployment; fi
    # }
  end
end
# after "deploy:update_code", "graphiti:link_configs"
# after "deploy:update_code", "bundler:install_gems"
after "deploy:update_code", "graphiti:compress"
