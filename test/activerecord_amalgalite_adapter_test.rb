require File.expand_path(File.join(File.dirname(__FILE__),"test_helper.rb"))


LOCAL_TEST_ROOT = File.dirname( __FILE__ ) 
$: << LOCAL_TEST_ROOT
require 'config'

require 'activerecord'
require 'rubygems'
require 'activesupport'
require 'activerecord-amalgalite-adapter'

FileUtils.rm_rf Dir.glob( "#{LOCAL_TEST_ROOT}/*.sqlite3" )
tests = Dir.glob("#{TEST_ROOT}/cases/*_test.rb").sort
puts "There are #{tests.size} test files in #{TEST_ROOT}/cases/"

#tests[0..4].each { |f| puts f ; load f }
tests.each { |f| load f }


