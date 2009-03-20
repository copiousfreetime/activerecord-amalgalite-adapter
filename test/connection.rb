print "Using native Amalgalite\n"
require_dependency 'models/course'
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

class AmalgaliteError< StandardError
end

BASE_DIR = FIXTURES_ROOT

this_dir = File.dirname( __FILE__ )
amalgalite_test_db  = File.expand_path( File.join( this_dir, "fixture_database.sqlite3" ) )
amalgalite_test_db2 = File.expand_path( File.join( this_dir, "fixture_database_2.sqlite3") )

def make_connection(clazz, db_file)
  ActiveRecord::Base.configurations = { clazz.name => { :adapter => 'amalgalite', :database => db_file } }
  unless File.exist?(db_file)
    puts "Amalgalite database not found at #{db_file}. Rebuilding it."
    sqlite_command = %Q{sqlite3 "#{db_file}" "create table a (a integer); drop table a;"}
    puts "Executing '#{sqlite_command}'"
    raise AmalgaliteError.new("Seems that there is no sqlite3 executable available") unless system(sqlite_command)
  end
  clazz.establish_connection(clazz.name)
end

puts "File.exist : #{File.exist?( amalgalite_test_db )}"
make_connection(ActiveRecord::Base, amalgalite_test_db)
make_connection(Course, amalgalite_test_db2)
