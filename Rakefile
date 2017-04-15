# encoding: utf-8

require "rubygems"
require "bundler"
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require "rake"

require "jeweler"
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://guides.rubygems.org/specification-reference/ for more options
  gem.name = "active_record_query_fixer"
  gem.homepage = "http://github.com/kaspernj/active_record_query_fixer"
  gem.license = "MIT"
  gem.summary = %(A library for automatically added `.select` on a column used for `.distinct` or automatically adding `.group` for a column used for order.)
  gem.description =
    %(A library for automatically added `.select` on a column used for `.distinct` or automatically adding `.group` for a column used for order.)
  gem.email = "kaspernj@gmail.com"
  gem.authors = ["kaspernj"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require "rspec/core"
require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList["spec/**/*_spec.rb"]
end

desc "Code coverage detail"
task :simplecov do
  ENV["COVERAGE"] = "true"
  Rake::Task["spec"].execute
end

task default: :spec

require "rdoc/task"
Rake::RDocTask.new do |rdoc|
  version = File.exist?("VERSION") ? File.read("VERSION") : ""

  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "active_record_query_fixer #{version}"
  rdoc.rdoc_files.include("README*")
  rdoc.rdoc_files.include("lib/**/*.rb")
end

require "best_practice_project"
BestPracticeProject.load_tasks
