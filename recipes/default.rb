#
# Cookbook Name:: tiny_mon
# Recipe:: default
#
# Copyright (C) 2013 YOUR_NAME
# 
# All rights reserved - Do Not Redistribute
#

include_recipe "apt"
include_recipe "git"
include_recipe "phantomjs"
include_recipe "rvm"
include_recipe "rvm::system_install"
include_recipe "mysql::server"
include_recipe "apache2"

rvm_ruby "1.9.3-p385" do
  action :install
end

include_recipe "passenger_apache2"

user "deploy" do
  gid "users"
  home "/home/deploy"
  shell "/bin/bash"
end

directory "/var/www/apps/tiny_mon/shared" do
  recursive true
  owner "deploy"
  group "users"
end

directory "/var/www/apps/tiny_mon/shared/log" do
  recursive true
  owner "deploy"
  group "users"
end

directory "/var/www/apps/tiny_mon/shared/pids" do
  recursive true
  owner "deploy"
  group "users"
end

template "/var/www/apps/tiny_mon/shared/database.yml" do
  source "database.yml.erb"
  mode 0755
  owner "deploy"
  group "users"
  variables :password => node[:mysql][:server_root_password]
end

template "/var/www/apps/tiny_mon/shared/config.yml" do
  source "config.yml.erb"
  mode 0755
  owner "deploy"
  group "users"
end

deploy_revision "/var/www/apps/tiny_mon" do
  repo "git://github.com/tkadauke/tiny_mon.git"
  revision "capybara"
  user "deploy"
  group "users"

  environment "RAILS_ENV" => "production"
  shallow_clone false
 
  action :force_deploy
 
  migrate true
  migration_command "/usr/local/rvm/bin/rvm 1.9.3-p385 exec bundle exec rake db:create:all db:migrate"
 
  before_migrate do
    rvm_shell "bundle install" do
      ruby_string "1.9.3-p385"
      cwd release_path
      user "deploy"
      group "users"
 
      code %{bundle install --path /var/www/apps/tiny_mon/shared/bundle}
    end
  end
 
  before_restart do
    rvm_shell "assets precompile" do
      ruby_string "1.9.3-p385"
      cwd release_path
      user "deploy"
      group "users"

      code %{
        export RAILS_ENV=production
        bundle exec rake assets:precompile
      }
    end
  end
 
  symlink_before_migrate "database.yml" => "config/database.yml",
                         "config.yml" => "config/config.yml"
end

web_app "tiny_mon" do
  docroot "/var/www/apps/tiny_mon/current/public"
  template "tiny_mon.conf.erb"
  server_name node[:fqdn]
  server_aliases [node[:hostname], "tiny_mon"]
  rails_env "production"
end
