require File.expand_path(File.join(File.dirname(__FILE__),"test_helper.rb"))

require 'activerecord'
require 'activesupport'

# load up the existing test cases from activerecord
source_index = Gem::SourceIndex.from_gems_in( *Gem::SourceIndex.installed_spec_directories )
ar_spec_list = source_index.find_name( 'activerecord' )
ar_spec = ar_spec_list.sort_by { |x| x.version }.last
ar_dir = ar_spec.full_gem_path
ar_test_dir = File.join( ar_dir, "test" )

require File.expand_path( File.join( ar_test_dir, 'config.rb' ) )

$: << File.dirname( __FILE__ ) 
$: << ar_test_dir

tests = Dir.glob("#{ar_test_dir}/cases/*_test.rb").sort

load tests.first 
#tests.each { |f| load f }


