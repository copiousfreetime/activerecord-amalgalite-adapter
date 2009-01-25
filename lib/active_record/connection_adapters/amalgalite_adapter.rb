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
    class AmalgaliteAdapter
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

      class Version
        MAJOR   = 0
        MINOR   = 0
        BUILD   = 1

        def self.to_a 
          [MAJOR, MINOR, BUILD]
        end

        def self.to_s
          to_a.join(".")
        end

        def to_a
          Version.to_a
        end
        def to_s
          Version.to_s
        end

        STRING = Version.to_s
      end
      VERSION = Version.to_s

    end
  end

end
