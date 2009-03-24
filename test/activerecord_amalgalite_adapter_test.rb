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

# %w[ aaa_create migration ].each do |k|
  # tests.each do  |f| 
    # if f =~ /#{k}/ then
      # puts f
      # load f
    # end
  # end
# end
#tests[0..32].each { |f| puts f ;  next if f =~ /base/;  load f }
tests.each { |f| puts f ; load f }


