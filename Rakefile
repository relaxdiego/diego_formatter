# encoding: utf-8

require 'rubygems'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "diego_formatter"
  gem.homepage = "http://github.com/relaxdiego/formatter"
  gem.license = "MIT"
  gem.summary = "Custom Cucumber formatter"
  gem.description = "Formats Cucumber's output in a way that is helpful to readers."
  gem.email = "mmaglana@gmail.com"
  gem.authors = ["Mark Maglana"]
end
Jeweler::RubygemsDotOrgTasks.new