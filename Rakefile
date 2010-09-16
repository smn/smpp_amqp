require 'rubygems'
require 'bundler/setup'
require 'spec/rake/spectask'

task :default => [:test]

desc "Run all tests"
Spec::Rake::SpecTask.new('test') do |t|
  t.spec_opts = ['--format', 'specdoc', '--color']
  t.spec_files = FileList['test/spec/*.rb']
end
