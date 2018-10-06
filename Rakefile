# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

# load tasks
Dir[File.join(__dir__, 'lib', 'tasks', '*.rake')].each { |f| load f }

RSpec::Core::RakeTask.new(:spec)

task :default => :spec
