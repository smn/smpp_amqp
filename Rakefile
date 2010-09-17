require 'rubygems'
require 'bundler/setup'
require 'spec/rake/spectask'
require 'smpp'
require 'smpp-amqp/amqp'

task :default => [:spec]

desc "Run all tests"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_opts = ['--format', 'specdoc', '--color']
  t.spec_files = FileList['test/spec/*.rb']
end

namespace :transport do
  desc "Start the transport"
  task :start do |t|
    config = YAML.load_file(ENV['CONFIG'] || 'config.yaml')
    Smpp::Amqp.new(config)
  end
end

