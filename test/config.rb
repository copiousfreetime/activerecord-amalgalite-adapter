
# load up the existing test cases from activerecord
# require 'rubygems'
#source_index = Gem::SourceIndex.from_gems_in( *Gem::SourceIndex.installed_spec_directories )
#ar_spec_list = source_index.find_name( 'activerecord' )
#ar_spec = ar_spec_list.sort_by { |x| x.version }.last
#ar_dir = ar_spec.full_gem_path
#AR_TEST_ROOT = File.join( ar_dir, "test" )
AR_ROOT = File.expand_path( "~/repos/git/rails/activerecord" )
#AR_ROOT = File.expand_path( "/opt/local/lib/ruby/gems/1.8/gems/activerecord-2.3.2" )

TEST_ROOT       = AR_ROOT + "/test"
ASSETS_ROOT     = TEST_ROOT + "/assets"
FIXTURES_ROOT   = TEST_ROOT + "/fixtures"
MIGRATIONS_ROOT = TEST_ROOT + "/migrations"
SCHEMA_ROOT     = LOCAL_TEST_ROOT + "/schema"

$: << TEST_ROOT
$: << File.join( AR_ROOT, "lib" )

