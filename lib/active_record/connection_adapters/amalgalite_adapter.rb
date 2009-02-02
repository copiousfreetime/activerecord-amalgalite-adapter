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
    class AmalgaliteColumn < Column
      def self.from_amalgalite( am_col )
        new( am_col.name,
             am_col.default_value,
             am_col.declared_data_type,
             am_col.nullable? )
      end
    end
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

      # QUOTING ==================================================

      # this is really escaping
      def quote_string( s ) #:nodoc:
        @connection.escape( s )
      end

      def quote_column_name( name ) #:nodoc:
        return "\"#{name}\""
      end

      # DATABASE STATEMENTS ======================================
      def execute( sql, name = nil )
        log( sql, name) { @connection.execute( sql ) }
      end

      def select( sql, name )
        execute( sql, name ).map do |row|
          row.to_hash
        end
      end

      def select_rows( sql, name = nil )
        execute( sql, name )
      end

      def update_sql( sql, name = nil )
        super
        @connection.row_changes
      end

      def insert_sql( sql, name = nil, pk = nil, id_value = nil, sequence_name = nil )
        super || @connection.last_insert_rowid
      end

      def begin_db_transaction() @connection.transaction; end
      def commit_db_transaction() @connection.commit; end
      def rollback_db_transaction() @connection.rollback; end

      # there is no select for update in sqlite
      def add_lock!( sql, options )
        sql
      end


      # SCHEMA STATEMENTS ========================================

      def default_primary_key_type
        'INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL'.freeze
      end

      def tables( name = nil )
        @connection.schema.tables.keys
      end

      def indexes( table_name, name = nil )
        table = @connection.schema.tables[table_name]
        indexes = []
        if table then
          indexes = table.indexes.map do |key, idx|
            index = IndexDefinition.new( table_name, idx.name )
            index.unique = idx.unique?
            index.columns = idx.columns.map { |col| col.name }
            index
          end
        end
        return indexes
      end

      def columns( table_name, name = nil )
        @connection.schema.tables[table_name].columns_in_order.map do |c|
          AmalgaliteColumn.from_amalgalite( c )
        end
      end

      ##
      # Wrap the create table so we can mark the schema as dirty
      #
      alias :ar_create_table :create_table
      def create_table( table_name, options = {}, &block )
        ar_create_table( table_name, options, &block )
        @connection.schema.load_table( table_name )
      end

      alias :ar_change_table :change_table
      def change_table( table_name, &block )
        ar_change_table( table_name, &block )
        @connection.schema.load_table( table_name )
      end

      def drop_table( table_name )
        execute( "DROP TABLE #{@connection.quote( table_name ) }" )
        @connection.schema.tables.delete( table_name )
      end

      alias :ar_add_column :add_column
      def add_column(table_name, column_name, type, options = {})
        ar_add_column( table_name, column_name, type, options )
        @connection.schema.load_table( table_name )
      end

      alias :ar_remove_column :remove_column
      def remove_column( table_name, *column_names )
        ar_remove_column( table_name, *column_names )
        @connection.schema.load_table( table_name )
      end

      alias :ar_add_index :add_index
      def add_index( table_name, column_name, options = {} )
        ar_add_index( table_name, column_name, options )
        @connection.schema.load_table( table_name )
      end

      alias :ar_remove_index :remove_index
      def remove_index( table_name, options = {} )
        ar_remove_index( table_name, options )
        @connection.schema.load_table( table_name )
      end
    end
  end

end
