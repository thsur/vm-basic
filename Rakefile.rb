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
require 'ostruct'

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

# Write ERB template files with given data to given destination.
# 
# Used here to write Ansible inventory & config files.
# 
# Cf.:
# - https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html
# - https://www.stuartellis.name/articles/erb/
# - https://www.rubyguides.com/2018/11/ruby-erb-haml-slim/
# - https://blog.appsignal.com/2019/01/08/ruby-magic-bindings-and-lexical-scope.html
def write_template(template, target, config)

  File.write(

    target,
    ERB.new(File.read(template)).result(binding)
  )
end

# Whether or not to generate, or update, Ansible inventory & confg files.
def generate_ansible_files
  
  # Helper to decide whether or not to generate/update a given file
  update = Proc.new do |fn, mtime|
    !(File.exists?(fn) && File.stat(fn).mtime >= mtime)
  end

  Dir.glob('./templates/ansible.*').each do |template|

    # Get a template's last modified date
    source_mtime = File.stat(template).mtime 

    # Get a destination's potential file name & path 
    target_file = File.basename(template).split('.').slice(1...-1).join('.') 
    target_path = target_file.start_with?('inventory') ? 'inventory' : 'plays/*'

    # Walk destination path(s)
    Dir.glob("./ansible/#{target_path}/").each do |path|

      # Build a potential real path
      fn = File.join(File.expand_path(path), target_file)    

      # Yield source (template file) & target if the target needs to be generated/updated
      yield template, fn if update.call(fn, source_mtime) && block_given?
    end 
  end
end

# 
# Settings
# 

# Get some base config structure.
# 
# For more options on how to do this, cf.:
# - https://www.cloudbees.com/blog/creating-configuration-objects-in-ruby/

config = OpenStruct.new

config.vm        = get_vagrant_config[:hostname]
config.ssh       = File.join(__dir__, 'vagrant/.ssh/config')
config.inventory = File.join(__dir__, 'ansible/inventory/inventory.yml')
config.roles     = File.join(__dir__, 'ansible/roles')

#
# Bootstrap
# 

generate_ansible_files do |template, target|
  write_template(template, target, config)
end

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
    cd('ansible/plays/provision') do
      begin
        sh "ansible-playbook -v playbook.yml"
      rescue RuntimeError; end
    end
  end

  desc 'Perform a provision dry run.'
  task :dry do
    cd('ansible/plays/provision') do
      begin
        sh "ansible-playbook --check -v playbook.yml"
      rescue RuntimeError; end  
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
    sh "ssh -F #{config.ssh} #{config.vm}"
  end

  desc 'Try to ping VM with Ansible, so we know Ansible is able to connect.'
  task :ping do
    sh "ansible #{config.vm} -i #{config.inventory} -m ping"
  end

  desc 'Whether or not memcached is running.'
  task :memcached do
    sh "ssh -F #{config.ssh} #{config.vm} 'echo stats | nc 127.0.0.1 11211'"
    sh "ssh -F #{config.ssh} #{config.vm} 'php -i | grep memcached'"
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