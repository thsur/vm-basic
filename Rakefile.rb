# Provide a Rake-based interface for building & provisioning 
# a dev environment based on Ansible & Vagrant.  
# 
# For Rake, cf.:
# - https://github.com/ruby/rake
# - https://martinfowler.com/articles/rake.html
# 
# Make sure to have Rake installed:
# $ gem install rake
# 
# Make sure to have all dependencies installed:
# $ gem install bundler
# $ bundle install

#
# Dependencies
# 

# stdlib
require 'yaml'
require 'pp'
require 'erb'

# Gems
# 
# For Rails' active support extensions, cf.:
# - https://guides.rubyonrails.org/active_support_core_extensions.html
require 'rubygems'
require 'bundler/setup'
require 'rake'
require 'awesome_print'
require 'active_support/core_ext/hash/keys'
require 'active_support/configurable'

#
# Helper functions
#

# Read basic Vagrant config. 
def get_vagrant_config
  YAML.load_file('./vagrant/config.yml').symbolize_keys
end

# Write Ansible inventory file.
# 
# Cf.:
# - https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html
# - https://www.stuartellis.name/articles/erb/
# - https://www.rubyguides.com/2018/11/ruby-erb-haml-slim/
# - https://blog.appsignal.com/2019/01/08/ruby-magic-bindings-and-lexical-scope.html
def write_ansible_inventory(data)

  return if (File.exists?(data[:file]) && !data[:force])

  File.write(

    data[:file],
    ERB.new(File.read('templates/inventory.yml.erb')).result(binding)
  )
end

# 
# Settings
# 

$vm        = get_vagrant_config[:hostname]
$inventory = 'ansible/inventory/inventory.yml'

#
# Setup
# 

write_ansible_inventory(host: $vm, file: $inventory)

# We do our own default help screen when no task was given.
# To get at the task descriptions, however, we need to tell Rake to record them before we load the task definitions in.
Rake::TaskManager.record_task_metadata = true

#
# Tasks
# 

namespace :vm do

  desc 'Bring dev machine up.'
  task :up do
    cd('vagrant') do
      sh 'vagrant up'
    end
  end

  desc 'Bring dev machine down.'
  task :halt do
    cd('vagrant') do
      sh 'vagrant halt'
    end
  end

  desc 'Bring dev machine down for good.'
  task :destroy do
    cd('vagrant') do
      sh 'vagrant destroy'
    end
  end

  desc 'Pause dev machine.'
  task :halt do
    cd('vagrant') do
      sh 'vagrant suspend'
    end
  end

  desc 'SSH into dev machine.'
  task :conn do
    cd('vagrant') do
      sh 'vagrant ssh'
    end
  end

  desc 'Reload dev machine after re-configuration.'
  task :reload do
    cd('vagrant') do
      sh 'vagrant reload --provision'
    end
  end

  desc 'Fix issues with non-existing synced folders.'
  task :fix_nfs do
    sh 'sudo rm /etc/exports'
    sh 'sudo touch /etc/exports'
  end 

  desc 'Get status of dev machine.'
  task :status do
    cd('vagrant') do
      sh 'vagrant status'
    end
  end
end

namespace :ansible do

  desc 'Provision dev machine.'
  task :provision do
    cd('ansible/provision') do
      sh "ansible-playbook -v -i #{$inventory} playbook.yml"
    end
  end

  desc 'Perform a provision dry run.'
  task :dry do
    cd('ansible/provision') do
      sh "ansible-playbook --check -v -i #{$inventory} playbook.yml"
    end
  end

  desc 'Update galaxy roles.'
  task :galaxy do
    cd('ansible') do
      sh 'ansible-galaxy install --roles-path=./roles/contrib -r requirements.yml'
    end
  end
end

namespace :test do
  
  desc 'Try to connect to VM via ssh & custom config file.'
  task :ssh do
    sh "ssh -F vagrant/.ssh/config #{$vm}"
  end

  desc 'Try to ping VM with Ansible, so we know Ansible is able to connect.'
  task :ping do
    sh "ansible #{$vm} -i #{$inventory} -m ping"
  end

  desc 'Whether or not memcached is running.'
  task :memcached do
    sh "ssh -F vagrant/.ssh/config #{$vm} 'echo stats | nc 127.0.0.1 11211'"
    sh "ssh -F vagrant/.ssh/config #{$vm} 'php -i | grep memcached'"
  end
end

namespace :core do

  desc 'Install dependencies so can operate properly.'
  task :install_dependencies do
    sh "bundle install"
  end

  desc 'Update Ansible inventory.'
  task :update_inventory do
    write_ansible_inventory(host: $vm, file: $inventory, force: true)
  end
end

#
# Help screen
# 

task :default do

  tasks = Rake.application.tasks
  desc  = {}

  puts
  puts 'VM'
  puts
  puts 'Usage:'
  puts 'rake TASK, e.g. rake ' + tasks[0].name
  puts

  tasks.each do |t|
    
    if t.scope && t.comment && t.full_comment

      scope = t.scope.entries[-1] || 'other'

      desc[scope] = [] unless desc.has_key?(scope)
      desc[scope].push([t.name, t.full_comment])
    end
  end

  desc.sort.each do |ns, tasks|

    title = "* #{ns.upcase} *"

    puts
    puts "-" * title.length
    puts title
    puts "-" * title.length
    puts

    tasks.each do |name, desc|
      
      puts sprintf("%s", name) 
      puts sprintf("  %s", desc) 
      puts
    end
  end
end