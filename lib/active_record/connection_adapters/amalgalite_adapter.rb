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
require 'stringio'

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

      # unfortunately, not able to use the Blob interface as that requires
      # knowing what column the blob is going to be stored in. Use the approach
      # in the sqlite3 driver.
      def self.string_to_binary( value )
        value.gsub(/\0|\%/n) do |b|
          case b
            when "\0" then "%00"
            when "%"  then "%25"
          end
        end
      end

      # since the type is blog, the amalgalite drive extracts it as a blob and we need to 
      # convert back into a string and do the substitution
      def self.binary_to_string(value)
        value.to_s.gsub(/%00|%25/n) do |b|
          case b
            when "%00" then "\0"
            when "%25" then "%"
          end
        end
      end

      # AR asks to convert a datetime column to a time and then passes in a
      # string... WTF ?
      def self.datetime_to_time( dt )
        case dt
        when String
          return nil if dt.empty?
        when DateTime
          return dt.to_time
        when Time
          return dt.to_time
        end
      end

      # active record assumes that type casting is from a string to a value, and
      # it might not be, mainly AR is an idiot when it comes to the driver
      # returns, as is approriate DateTime values when the declared data ttype
      # is datetime.  in that case AR wants a Time obj backi
      def type_cast_code( var_name )
        case type 
        when :datetime   then "#{self.class.name}.datetime_to_time(#{var_name})"
        else
          super
        end
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

      def supports_ddl_transactions?
        true
      end

      def supports_migrations?
        true
      end

      def requires_reloading?
        true
      end

      def supports_add_column?
        true
      end

      def supports_count_distinct?
        true
      end

      def supports_autoincrement?
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

      def update_sql( sql, name = nil )
        super
        @connection.row_changes
      end

      def delete_sql(sql, name = nil )
        sql += "WHERE 1=1" unless sql =~ /WHERE/i
        super sql, name
      end

      def insert_sql( sql, name = nil, pk = nil, id_value = nil, sequence_name = nil )
        super || @connection.last_insert_rowid
      end

      def select_rows( sql, name = nil )
        execute( sql, name )
      end

      def select( sql, name = nil )
        execute( sql, name ).map do |row|
          row.to_hash
        end
      end


      def begin_db_transaction() @connection.transaction; end
      def commit_db_transaction() @connection.commit; end
      def rollback_db_transaction() @connection.rollback; @connection.schema.dirty!; end

      # there is no select for update in sqlite
      def add_lock!( sql, options )
        sql
      end


      # SCHEMA STATEMENTS ========================================

      def default_primary_key_type
        'INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL'.freeze
      end

      def tables( name = nil )
        sql = "SELECT name FROM sqlite_master WHERE type = 'table' AND NOT name = 'sqlite_sequence'" 
        raw_list = execute( sql, nil ).map { |row| row['name'] }
        if raw_list.sort != @connection.schema.tables.keys.sort then
          @connection.schema.load_schema!
          if raw_list.sort != @connection.schema.tables.keys.sort then
            raise "raw_list - tables : #{raw_list - @connection.schema.tables.keys} :: tables - raw_list #{@connection.schema.tables.keys - raw_list}"
          end
        end
        ActiveRecord::Base.logger.info "schema_migrations    in tables? : #{raw_list.include?( "schema_migrations" )}"
        ActiveRecord::Base.logger.info "schema_migrations(2) in tables? : #{@connection.schema.tables.keys.include?( "schema_migrations" )}"
        @connection.schema.tables.keys
      end

      def columns( table_name, name = nil )
        t = @connection.schema.tables[table_name.to_s]
        raise "Invalid table #{table_name}" unless t
        t.columns_in_order.map do |c|
          AmalgaliteColumn.from_amalgalite( c )
        end
      end

      def indexes( table_name, name = nil )
        table = @connection.schema.tables[table_name.to_s]
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

      def primary_key( table_name )
        pk_list = @connection.schema.tables[table_name.to_s].primary_key
        if pk_list.empty? then
          return nil
        else
          return pk_list.first.name
        end
      end

      def remove_index( table_name, options = {} )
        execute "DROP INDEX #{quote_column_name(index_name( table_name.to_s, options ) ) }"
        @connection.schema.dirty!
      end

      def rename_table( name, new_name )
        execute "ALTER TABLE #{name} RENAME TO #{new_name}"
        @connection.schema.dirty!
      end

      # See: http://www.sqlite.org/lang_altertable.html
      # SQLite has an additional restriction on the ALTER TABLE statement
      def valid_alter_table_options( type, options )
        type.to_sym != :primary_key
      end

      ##
      # Wrap the create table so we can mark the schema as dirty
      #
      def create_table( table_name, options = {}, &block )
        super( table_name, options, &block )
        @connection.schema.load_table( table_name.to_s )
      end

      def change_table( table_name, &block )
        super( table_name, &block )
        @connection.schema.load_table( table_name.to_s )

      end

      def drop_table( table_name, options = {} )
        super( table_name, options )
        @connection.schema.tables.delete( table_name.to_s )
        puts "dropped table #{table_name} : #{@connection.schema.tables.include?( table_name )}" if table_name == "delete_me"
      end

      def add_column(table_name, column_name, type, options = {})
        rc = nil
        if valid_alter_table_options( type, options ) then
          rc = super( table_name, column_name, type, options )
        else
          table_name = table_name.to_s
          rc = alter_table( table_name ) do |definition|
            definition.column( column_name, type, options )
          end
        end
        @connection.schema.load_table( table_name.to_s )
        return rc
      end

      def add_index( table_name, column_name, options = {} )
        super
        @connection.schema.load_table( table_name.to_s )
      end

      def remove_column( table_name, *column_names )
        column_names.flatten.each do |column_name|
          alter_table( table_name ) do |definition|
            definition.columns.delete( definition[column_name] )
          end
        end
      end
      alias :remove_columns :remove_column

      def change_column_default(table_name, column_name, default) #:nodoc:
        alter_table(table_name) do |definition|
          definition[column_name].default = default
        end
      end

      def change_column_null(table_name, column_name, null, default = nil)
        unless null || default.nil?
          execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
        end
        alter_table(table_name) do |definition|
          definition[column_name].null = null
        end
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        alter_table(table_name) do |definition|
          include_default = options_include_default?(options)
          definition[column_name].instance_eval do
            self.type    = type
            self.limit   = options[:limit] if options.include?(:limit)
            self.default = options[:default] if include_default
            self.null    = options[:null] if options.include?(:null)
          end
        end
      end

      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        unless columns(table_name).detect{|c| c.name == column_name.to_s }
          raise ActiveRecord::ActiveRecordError, "Missing column #{table_name}.#{column_name}"
        end
        alter_table(table_name, :rename => {column_name.to_s => new_column_name.to_s})
      end

      def empty_insert_statement(table_name)
        "INSERT INTO #{table_name} VALUES(NULL)"
      end

      #################
      protected
      #################

      def alter_table(table_name, options = {}) #:nodoc:
        altered_table_name = "altered_#{table_name}"
        caller = lambda {|definition| yield definition if block_given?}

        transaction do
          move_table(table_name, altered_table_name,
                     options.merge(:temporary => true))
          move_table(altered_table_name, table_name, &caller)
        end
      end

      def move_table(from, to, options = {}, &block) #:nodoc:
        copy_table(from, to, options, &block)
        drop_table(from)
      end

      def copy_table(from, to, options = {}) #:nodoc:
        options = options.merge( :id => (!columns(from).detect{|c| c.name == 'id'}.nil? && 'id' == primary_key(from).to_s))
        options = options.merge( :primary_key => primary_key(from).to_s )
        create_table(to, options) do |definition|
          @definition = definition
          columns(from).each do |column|
            column_name = options[:rename] ?
              (options[:rename][column.name] ||
               options[:rename][column.name.to_sym] ||
               column.name) : column.name

            @definition.column(column_name, column.type,
                               :limit => column.limit, :default => column.default,
                               :null => column.null)
          end
          @definition.primary_key(primary_key(from)) if primary_key(from)
          yield @definition if block_given?
        end

        copy_table_indexes(from, to, options[:rename] || {})
        copy_table_contents(from, to,
                            @definition.columns.map {|column| column.name},
                            options[:rename] || {})
      end

      def copy_table_indexes(from, to, rename = {}) #:nodoc:
        indexes(from).each do |index|
          name = index.name
          if to == "altered_#{from}"
            name = "temp_#{name}"
          elsif from == "altered_#{to}"
            name = name[5..-1]
          end

          to_column_names = columns(to).map(&:name)
          columns = index.columns.map {|c| rename[c] || c }.select do |column|
            to_column_names.include?(column)
          end

          unless columns.empty?
            # index name can't be the same
            opts = { :name => name.gsub(/_(#{from})_/, "_#{to}_") }
            opts[:unique] = true if index.unique
            add_index(to, columns, opts)
          end
        end
      end

      def copy_table_contents(from, to, columns, rename = {}) #:nodoc:
        column_mappings = Hash[*columns.map {|name| [name, name]}.flatten]
        rename.inject(column_mappings) {|map, a| map[a.last] = a.first; map}
        from_columns = columns(from).collect {|col| col.name}
        columns = columns.find_all{|col| from_columns.include?(column_mappings[col])}
        quoted_columns = columns.map { |col| quote_column_name(col) } * ','

        quoted_to = quote_table_name(to)
        @connection.execute "SELECT * FROM #{quote_table_name(from)}" do |row|
          sql = "INSERT INTO #{quoted_to} (#{quoted_columns}) VALUES ("
          sql << columns.map {|col| quote row[column_mappings[col]]} * ', '
          sql << ')'
          @connection.execute sql
        end
      end
    end
  end
end
