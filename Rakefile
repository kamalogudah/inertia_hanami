# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: %i[test rubocop]
