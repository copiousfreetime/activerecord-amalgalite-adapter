#--
# Copyright (c) 2009 Jeremy Hinegadner
# All rights reserved.  See LICENSE and/or COPYING for details
#
# much of this behavior ported from the standard active record sqlite 
# and sqlite3 # adapters
#++
require 'active_record'
require 'active_record/connection_adapters/abstract_adapter'
require 'amalgalite'

module ActiveRecord
  class Base
    class << self
      def amalgalite_connection( config ) # :nodoc:
        config[:database] ||= config[:dbfile]
        raise ArgumentError, "No database file specified.  Missing argument: database" unless config[:database]

        # Allow database path relative to RAILS_ROOT, but only if the database
        # is not the in memory database
        if Object.const_defined?( :RAILS_ROOT ) and (":memory:" != config[:database] ) then
          config[:database] = File.expand_path( config[:database], RAILS_ROOT )
        end

        db = ::Amalgalite::Database.new( config[:database] )
        ConnectionAdapters::AmalgaliteAdapter.new( db, logger )
      end
    end
  end


  module ConnectionAdapters
    class AmalgaliteAdapter < AbstractAdapter
       class Version
        MAJOR   = 0
        MINOR   = 0
        BUILD   = 1

        def self.to_a() [MAJOR, MINOR, BUILD]; end
        def self.to_s() to_a.join("."); end
        def to_a()      Version.to_a; end
        def to_s()       Version.to_s; end

        STRING = Version.to_s
      end

      VERSION = Version.to_s

      def adapter_name
        "Amalgalite"
      end

      def supports_migrations?
        true
      end

      def requires_reloading?
        true
      end

      def supports_count_distinct?
        true
      end

      def supports_ddl_transactions?
        true
      end

      def native_database_types #:nodoc:
        {
          :primary_key => default_primary_key_type,
          :string      => { :name => "varchar", :limit => 255 },
          :text        => { :name => "text" },
          :integer     => { :name => "integer" },
          :float       => { :name => "float" },
          :decimal     => { :name => "decimal" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "datetime" },
          :time        => { :name => "time" },
          :date        => { :name => "date" },
          :binary      => { :name => "blob" },
          :boolean     => { :name => "boolean" }
        }
      end

      # DATABASE STATEMENTS ======================================
      def execute( sql, name = nil )
        log( sql, name) { @connection.execute( sql ) }
      end

      # SCHEMA STATEMENTS ========================================

      def default_primary_key_type
        'INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL'.freeze
      end

      def tables( name = nil )
        @connection.schema.tables.keys
      end

   end
  end

end
