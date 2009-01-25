require File.expand_path(File.join(File.dirname(__FILE__),"test_helper.rb"))

require 'activerecord'
require 'activesupport'

LOCAL_TEST_ROOT = File.dirname( __FILE__ ) 
$: << LOCAL_TEST_ROOT
require 'config'

tests = Dir.glob("#{AR_TEST_ROOT}/cases/*_test.rb").sort

tests[0..2].each { |f| load f }
#tests.each { |f| load f }


