
# load up the existing test cases from activerecord
source_index = Gem::SourceIndex.from_gems_in( *Gem::SourceIndex.installed_spec_directories )
ar_spec_list = source_index.find_name( 'activerecord' )
ar_spec = ar_spec_list.sort_by { |x| x.version }.last
ar_dir = ar_spec.full_gem_path
AR_TEST_ROOT = File.join( ar_dir, "test" )

TEST_ROOT       = AR_TEST_ROOT
ASSETS_ROOT     = TEST_ROOT + "/assets"
FIXTURES_ROOT   = TEST_ROOT + "/fixtures"
MIGRATIONS_ROOT = TEST_ROOT + "/migrations"
SCHEMA_ROOT     = LOCAL_TEST_ROOT + "/schema"

$: << TEST_ROOT

