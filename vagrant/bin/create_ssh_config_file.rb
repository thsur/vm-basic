#!/usr/bin/env ruby

# Create a SSH config file based on the output
# of vagrant ssh-config.

dir  = File.join(File.dirname(__dir__), '.ssh')
file = File.join(dir, 'config')

# Make sure the directory we want to write to exists.

Dir.mkdir(dir) unless File.exists?(dir)

# vagrant ssh-config takes a sec to execute,
# so proceed only if we do not have a file in place yet.

if !File.exists?(file)
  system("vagrant ssh-config > #{file}") 
end
