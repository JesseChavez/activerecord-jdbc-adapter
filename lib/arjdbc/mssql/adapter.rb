# frozen_string_literal: true

ArJdbc.load_java_part :MSSQL

require 'arel'
require 'arel/visitors/sqlserver'
require 'active_record/connection_adapters/abstract_adapter'

require 'arjdbc/mssql/extensions/attribute_methods'
require 'arjdbc/mssql/extensions/calculations'

require 'arjdbc/abstract/core'
require 'arjdbc/abstract/connection_management'
require 'arjdbc/abstract/database_statements'
require 'arjdbc/abstract/statement_cache'
require 'arjdbc/abstract/transaction_support'

require 'arjdbc/mssql/column'
require 'arjdbc/mssql/types'
require 'arjdbc/mssql/quoting'
require 'arjdbc/mssql/schema_definitions'
require 'arjdbc/mssql/schema_statements'
require 'arjdbc/mssql/schema_dumper'
require 'arjdbc/mssql/database_statements'
require 'arjdbc/mssql/explain_support'
require 'arjdbc/mssql/transaction'
require 'arjdbc/mssql/errors'
require 'arjdbc/mssql/schema_creation'
require 'arjdbc/mssql/database_limits'

module ActiveRecord
  module ConnectionAdapters
    # MSSQL (SQLServer) adapter class definition
    class MSSQLAdapter < AbstractAdapter
      ADAPTER_NAME = 'MSSQL'.freeze

      MSSQL_VERSION_YEAR = {
        8 => '2000',
        9 => '2005',
        10 => '2008',
        11 => '2012',
        12 => '2014',
        13 => '2016',
        14 => '2017',
        15 => '2019'
      }.freeze

      include Jdbc::ConnectionPoolCallbacks
      include ArJdbc::Abstract::Core
      include ArJdbc::Abstract::ConnectionManagement
      include ArJdbc::Abstract::DatabaseStatements
      include ArJdbc::Abstract::StatementCache
      include ArJdbc::Abstract::TransactionSupport

      include MSSQL::Quoting
      include MSSQL::SchemaStatements
      include MSSQL::DatabaseStatements
      include MSSQL::ExplainSupport
      include MSSQL::DatabaseLimits

      @cs_equality_operator = 'COLLATE Latin1_General_CS_AS_WS'

      class << self
        attr_accessor :cs_equality_operator
      end

      def initialize(connection, logger, _connection_parameters, config = {})
        # configure_connection happens in super
        super(connection, logger, config)

        if database_version < '11'
          raise "Your #{mssql_product_name} #{mssql_version_year} is too old. This adapter supports #{mssql_product_name} >= 2012."
        end
      end

      def self.database_exists?(config)
        !!ActiveRecord::Base.sqlserver_connection(config)
      rescue ActiveRecord::JDBCError => e
        case e.message
        when /Cannot open database .* requested by the login/
          false
        else
          raise
        end
      end

      # Returns the (JDBC) connection class to be used for this adapter.
      # The class is defined in the java part
      def jdbc_connection_class(_spec)
        ::ActiveRecord::ConnectionAdapters::MSSQLJdbcConnection
      end

      # Returns the (JDBC) `ActiveRecord` column class for this adapter.
      # Used in the java part.
      def jdbc_column_class
        ::ActiveRecord::ConnectionAdapters::MSSQLColumn
      end

      # Does this adapter support DDL rollbacks in transactions? That is, would
      # CREATE TABLE or ALTER TABLE get rolled back by a transaction?
      def supports_ddl_transactions?
        true
      end

      # Does this adapter support creating foreign key constraints?
      def supports_foreign_keys?
        true
      end

      # Does this adapter support setting the isolation level for a transaction?
      def supports_transaction_isolation?
        true
      end

      def supports_savepoints?
        true
      end

      def supports_lazy_transactions?
        true
      end

      # The MSSQL datetime type doe have precision.
      def supports_datetime_with_precision?
        true
      end

      # Does this adapter support index sort order?
      def supports_index_sort_order?
        true
      end

      # Also known as filtered index
      def supports_partial_index?
        true
      end

      # Does this adapter support views?
      def supports_views?
        true
      end

      def supports_insert_on_conflict?
        false
      end
      alias supports_insert_on_duplicate_skip? supports_insert_on_conflict?
      alias supports_insert_on_duplicate_update? supports_insert_on_conflict?
      alias supports_insert_conflict_target? supports_insert_on_conflict?

      def build_insert_sql(insert) # :nodoc:
        # TODO: hope we can implement an upsert like feature
        "INSERT #{insert.into} #{insert.values_list}"
      end

      # Overrides abstract method which always returns false
      def valid_type?(type)
        !native_database_types[type].nil?
      end

      def clear_cache!
        reload_type_map
        super
      end

      def reset!
        # execute 'IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION'
        # NOTE: it seems the above line interferes with the jdbc driver
        # and ending up in connection closed, issue seen in rails 5.2 and 6.0
        reconnect!
      end

      def disable_referential_integrity
        tables = tables_with_referential_integrity

        tables.each do |table_name|
          execute "ALTER TABLE #{table_name} NOCHECK CONSTRAINT ALL"
        end
        yield
      ensure
        tables.each do |table_name|
          execute "ALTER TABLE #{table_name} CHECK CONSTRAINT ALL"
        end
      end

      # Overrides the method in abstract adapter to set the limit and offset
      # in the right order. (SQLServer specific)
      # Called by bound_attributes
      def combine_bind_parameters(
        from_clause: [],
        join_clause: [],
        where_clause: [],
        having_clause: [],
        limit: nil,
        offset: nil
      )

        result = from_clause + join_clause + where_clause + having_clause
        result << offset if offset
        result << limit if limit
        result
      end

      # Returns the name of the current security context
      def current_user
        @current_user ||= select_value('SELECT CURRENT_USER')
      end

      # Returns the default schema (to be used for table resolution)
      # used for the {#current_user}.
      def default_schema
        @default_schema ||= select_value('SELECT default_schema_name FROM sys.database_principals WHERE name = CURRENT_USER')
      end

      alias_method :current_schema, :default_schema

      # Allows for changing of the default schema.
      # (to be used during unqualified table name resolution).
      def default_schema=(default_schema)
        execute("ALTER #{current_user} WITH DEFAULT_SCHEMA=#{default_schema}")
        @default_schema = nil if defined?(@default_schema)
      end

      alias_method :current_schema=, :default_schema=

      # FIXME: This needs to be fixed when we implement the collation per
      # column basis. At the moment we only use the global database collation
      def default_uniqueness_comparison(attribute, value) # :nodoc:
        column = column_for_attribute(attribute)

        if [:string, :text].include?(column.type) && collation && !collation.match(/_CS/) && !value.nil?
          # NOTE: there is a deprecation warning here in the mysql adapter
          # no sure if it's required.
          attribute.eq(Arel::Nodes::Bin.new(value))
        else
          super
        end
      end

      def case_sensitive_comparison(attribute, value)
        column = column_for_attribute(attribute)

        if [:string, :text].include?(column.type) && collation && !collation.match(/_CS/) && !value.nil?
          attribute.eq(Arel::Nodes::Bin.new(value))
        else
          super
        end
      end

      def configure_connection
        # Here goes initial settings per connection

        set_session_transaction_isolation
      end

      def set_session_transaction_isolation
        isolation_level = config[:transaction_isolation]

        self.transaction_isolation = isolation_level if isolation_level
      end

      def mssql?
        true
      end

      def mssql_major_version
        return @mssql_major_version if defined? @mssql_major_version

        @mssql_major_version = @connection.database_major_version
      end

      def mssql_version_year
        MSSQL_VERSION_YEAR[mssql_major_version.to_i]
      end

      def mssql_product_version
        return @mssql_product_version if defined? @mssql_product_version

        @mssql_product_version = @connection.database_product_version
      end

      def mssql_product_name
        return @mssql_product_name if defined? @mssql_product_name

        @mssql_product_name = @connection.database_product_name
      end

      def get_database_version # :nodoc:
        MSSQLAdapter::Version.new(mssql_product_version)
      end

      def check_version # :nodoc:
        # NOTE: hitting the database from here causes trouble when adapter
        # uses JNDI or Data Source setup.
      end

      def tables_with_referential_integrity
        schema_and_tables_sql = %(
          SELECT s.name, o.name
          FROM sys.foreign_keys i
          INNER JOIN sys.objects o ON i.parent_object_id = o.OBJECT_ID
          INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
        ).squish

        schemas_and_tables = select_rows(schema_and_tables_sql)

        schemas_and_tables.map do |schema_table|
          schema, table = schema_table
          "#{quote_name_part(schema)}.#{quote_name_part(table)}"
        end
      end

      private

      def translate_exception(exception, message:, sql:, binds:)
        case message
        when /no connection available/i
          ConnectionNotEstablished.new(exception)
        when /(cannot insert duplicate key .* with unique index) | (violation of unique key constraint)/i
          RecordNotUnique.new(message, sql: sql, binds: binds)
        when /Lock request time out period exceeded/i
          LockTimeout.new(message, sql: sql, binds: binds)
        when /The .* statement conflicted with the FOREIGN KEY constraint/
          InvalidForeignKey.new(message, sql: sql, binds: binds)
        when /The .* statement conflicted with the REFERENCE constraint/
          InvalidForeignKey.new(message, sql: sql, binds: binds)
        when /(String or binary data would be truncated)/i
          ValueTooLong.new(message, sql: sql, binds: binds)
        when /Cannot insert the value NULL into column .* does not allow nulls/
          NotNullViolation.new(message, sql: sql, binds: binds)
        when /Arithmetic overflow error converting expression/
          RangeError.new(message, sql: sql, binds: binds)
        else
          super
        end
      end

      # This method is called indirectly by the abstract method
      # 'fetch_type_metadata' which then it is called by the java part when
      # calculating a table's columns.
      def initialize_type_map(map = type_map)
        # Build the type mapping from SQL Server to ActiveRecord

        # Integer types.
        map.register_type 'int',      MSSQL::Type::Integer.new(limit: 4)
        map.register_type 'tinyint',  MSSQL::Type::TinyInteger.new(limit: 1)
        map.register_type 'smallint', MSSQL::Type::SmallInteger.new(limit: 2)
        map.register_type 'bigint',   MSSQL::Type::BigInteger.new(limit: 8)

        # Exact Numeric types.
        map.register_type %r{\Adecimal}i do |sql_type|
          scale = extract_scale(sql_type)
          precision = extract_precision(sql_type)
          if scale == 0
            MSSQL::Type::DecimalWithoutScale.new(precision: precision)
          else
            MSSQL::Type::Decimal.new(precision: precision, scale: scale)
          end
        end
        map.register_type %r{\Amoney\z}i,      MSSQL::Type::Money.new
        map.register_type %r{\Asmallmoney\z}i, MSSQL::Type::SmallMoney.new

        # Approximate Numeric types.
        map.register_type %r{\Afloat\z}i,    MSSQL::Type::Float.new
        map.register_type %r{\Areal\z}i,     MSSQL::Type::Real.new

        # Character strings CHAR and VARCHAR (it can become Unicode UTF-8)
        map.register_type 'varchar(max)', MSSQL::Type::VarcharMax.new
        map.register_type %r{\Avarchar\(\d+\)} do |sql_type|
          limit = extract_limit(sql_type)
          MSSQL::Type::Varchar.new(limit: limit)
        end
        map.register_type %r{\Achar\(\d+\)} do |sql_type|
          limit = extract_limit(sql_type)
          MSSQL::Type::Char.new(limit: limit)
        end

        # Character strings NCHAR and NVARCHAR (by default Unicode UTF-16)
        map.register_type %r{\Anvarchar\(\d+\)} do |sql_type|
          limit = extract_limit(sql_type)
          MSSQL::Type::Nvarchar.new(limit: limit)
        end
        map.register_type %r{\Anchar\(\d+\)} do |sql_type|
          limit = extract_limit(sql_type)
          MSSQL::Type::Nchar.new(limit: limit)
        end
        map.register_type 'nvarchar(max)', MSSQL::Type::NvarcharMax.new
        map.register_type 'nvarchar(4000)', MSSQL::Type::Nvarchar.new

        # Binary data types.
        map.register_type              'varbinary(max)',       MSSQL::Type::VarbinaryMax.new
        register_class_with_limit map, %r{\Abinary\(\d+\)},    MSSQL::Type::BinaryBasic
        register_class_with_limit map, %r{\Avarbinary\(\d+\)}, MSSQL::Type::Varbinary

        # Miscellaneous types, Boolean, XML, UUID
        # FIXME The xml data needs to be reviewed and fixed
        map.register_type 'bit',                     MSSQL::Type::Boolean.new
        map.register_type %r{\Auniqueidentifier\z}i, MSSQL::Type::UUID.new
        map.register_type %r{\Axml\z}i,              MSSQL::Type::XML.new

        # Date and time types
        map.register_type 'date',          MSSQL::Type::Date.new
        map.register_type 'datetime',      MSSQL::Type::DateTime.new
        map.register_type 'smalldatetime', MSSQL::Type::SmallDateTime.new
        register_class_with_precision map, %r{\Atime\(\d+\)}i, MSSQL::Type::Time
        map.register_type 'time(7)',       MSSQL::Type::Time.new
        register_class_with_precision map, %r{\Adatetime2\(\d+\)}i, MSSQL::Type::DateTime2
        map.register_type 'datetime2(7)',  MSSQL::Type::DateTime2.new

        # TODO: we should have identity separated from the sql_type
        # let's say in another attribute (this will help to pass more AR tests),
        # also we add collation attribute per column.
        # aliases
        map.alias_type 'int identity',    'int'
        map.alias_type 'bigint identity', 'bigint'
        map.alias_type 'integer',         'int'
        map.alias_type 'integer',         'int'
        map.alias_type 'INTEGER',         'int'
        map.alias_type 'TINYINT',         'tinyint'
        map.alias_type 'SMALLINT',        'smallint'
        map.alias_type 'BIGINT',          'bigint'
        map.alias_type %r{\Anumeric}i,    'decimal'
        map.alias_type %r{\Anumber}i,     'decimal'
        map.alias_type %r{\Adouble\z}i,   'float'
        map.alias_type 'string',          'nvarchar(4000)'
        map.alias_type %r{\Aboolean\z}i,  'bit'
        map.alias_type 'DATE',            'date'
        map.alias_type 'DATETIME',        'datetime'
        map.alias_type 'SMALLDATETIME',   'smalldatetime'
        map.alias_type %r{\Atime\z}i,     'time(7)'
        map.alias_type %r{\Abinary\z}i,   'varbinary(max)'
        map.alias_type %r{\Ablob\z}i,     'varbinary(max)'
        map.alias_type %r{\Adatetime2\z}i, 'datetime2(7)'

        # Deprecated SQL Server types.
        map.register_type 'text',  MSSQL::Type::Text.new
        map.register_type 'ntext', MSSQL::Type::Ntext.new
        map.register_type 'image', MSSQL::Type::Image.new
      end

      # Returns an array of Column objects for the table specified by +table_name+.
      # See the concrete implementation for details on the expected parameter values.
      # NOTE: This is ready, all implemented in the java part of adapter,
      # it uses MSSQLColumn, SqlTypeMetadata, etc.
      def column_definitions(table_name)
       log('JDBC: GETCOLUMNS', 'SCHEMA') { @connection.columns(table_name) }
      rescue => e
        # raise translate_exception_class(e, nil)
        # FIXME: this breaks one arjdbc test but fixes activerecord tests
        # (table name alias). Also it behaves similarly to the CRuby adapter
        # which returns an empty array too. (postgres throws a exception)
        []
      end

      def arel_visitor # :nodoc:
        ::Arel::Visitors::SQLServer.new(self)
      end

      def build_statement_pool
        # NOTE: @statements is set in StatementCache module
      end
    end
  end
end

# FIXME: this is not used by the adapter anymore, it is here because
# it is a dependency of old tests that needs to be reviewed
module ArJdbc
  module MSSQL
    require 'arjdbc/mssql/utils'
    require 'arjdbc/mssql/limit_helpers'
    require 'arjdbc/mssql/lock_methods'

    include LimitHelpers
    include Utils
  end
end
