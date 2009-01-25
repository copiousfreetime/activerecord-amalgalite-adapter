require 'tasks/config'
#-------------------------------------------------------------------------------
# configuration for running unit tests.  This shows up as the test:default task
#-------------------------------------------------------------------------------

if test_config = Configuration.for_if_exist?('test') then
  if test_config.mode == "testunit" then
    namespace :test do

      task :default => :test

      require 'rake/testtask'
      Rake::TestTask.new do |t| 
        t.test_files = FileList["test/*_test.rb"]
        t.verbose    = true
      end
    end
  end
end
