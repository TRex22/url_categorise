require "bundler/gem_tasks"
require "bundler/setup"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.ruby_opts = ["-rbundler/setup"]
end

task :default => :test
