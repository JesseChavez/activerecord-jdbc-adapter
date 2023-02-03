# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module SchemaStatements # :nodoc:

        NATIVE_DATABASE_TYPES = {
          # Logical Rails types to SQL Server types
          primary_key:   'bigint NOT NULL IDENTITY(1,1) PRIMARY KEY',
          integer:       { name: 'int', limit: 4 },
          boolean:       { name: 'bit' },
          decimal:       { name: 'decimal' },
          float:         { name: 'float' },
          date:          { name: 'date' },
          time:          { name: 'time' },
          datetime:      { name: 'datetime2' },
          string:        { name: 'nvarchar', limit: 4000 },
          text:          { name: 'nvarchar(max)' },
          binary:        { name: 'varbinary(max)' },
          # Other types or SQL Server specific
          bigint:        { name: 'bigint' },
          smalldatetime: { name: 'smalldatetime' },
          datetime_basic: { name: 'datetime' },
          timestamp:     { name: 'datetime' },
          real:          { name: 'real' },
          money:         { name: 'money' },
          smallmoney:    { name: 'smallmoney' },
          char:          { name: 'char' },
          nchar:         { name: 'nchar' },
          varchar:       { name: 'varchar', limit: 8000 },
          varchar_max:   { name: 'varchar(max)' },
          uuid:          { name: 'uniqueidentifier' },
          binary_basic:  { name: 'binary' },
          varbinary:     { name: 'varbinary', limit: 8000 },
          # Deprecated SQL Server types
          image:         { name: 'image' },
          ntext:         { name: 'ntext' },
          text_basic:    { name: 'text' }
        }.freeze

        def native_database_types
          NATIVE_DATABASE_TYPES
        end

        # Returns an array of indexes for the given table.
        def indexes(table_name)
          data = select("EXEC sp_helpindex #{quote(table_name)}", "SCHEMA") rescue []

          data.reduce([]) do |indexes, index|
            index = index.with_indifferent_access

            if index[:index_description] =~ /primary key/
              indexes
            else
              name    = index[:index_name]
              unique  = index[:index_description].to_s.match?(/unique/)
              where   = select_value("SELECT [filter_definition] FROM sys.indexes WHERE name = #{quote(name)}")
              orders  = {}
              columns = []

              index[:index_keys].split(',').each do |column|
                column.strip!

                if column.ends_with?('(-)')
                  column.gsub! '(-)', ''
                  orders[column] = :desc
                end

                columns << column
              end

              indexes << IndexDefinition.new(table_name, name, unique, columns, where: where, orders: orders)
            end
          end
        end

        def primary_keys(table_name)
          @connection.primary_keys(table_name)
        end

        def foreign_keys(table_name)
          @connection.foreign_keys(table_name)
        end

        def charset
          select_value "SELECT SqlCharSetName = CAST(SERVERPROPERTY('SqlCharSetName') AS NVARCHAR(128))"
        end

        def collation
          @collation ||= select_value("SELECT Collation = CAST(SERVERPROPERTY('Collation') AS NVARCHAR(128))")
        end

        def current_database
          select_value 'SELECT DB_NAME()'
        end

        def use_database(database = nil)
          database ||= config[:database]
          execute "USE #{quote_database_name(database)}" unless database.blank?
        end

        def drop_database(name)
          current_db = current_database
          use_database('master') if current_db.to_s == name
          # Only SQL Server 2016 onwards:
          # execute "DROP DATABASE IF EXISTS #{quote_database_name(name)}"
          execute "IF EXISTS(SELECT name FROM sys.databases WHERE name='#{name}') DROP DATABASE #{quote_database_name(name)}"
        end

        def create_database(name, options = {})
          edition_options = create_db_edition_options(options)

          if options[:collation] && edition_options.present?
            execute "CREATE DATABASE #{quote_database_name(name)} COLLATE #{options[:collation]} (#{edition_options.join(', ')})"
          elsif options[:collation]
            execute "CREATE DATABASE #{quote_database_name(name)} COLLATE #{options[:collation]}"
          elsif edition_options.present?
            execute "CREATE DATABASE #{quote_database_name(name)} (#{edition_options.join(', ')})"
          else
            execute "CREATE DATABASE #{quote_database_name(name)}"
          end
        end

        def recreate_database(name, options = {})
          drop_database(name)
          create_database(name, options)
        end

        def remove_column(table_name, column_name, type = nil, options = {})
          raise ArgumentError.new('You must specify at least one column name.  Example: remove_column(:people, :first_name)') if column_name.is_a? Array

          return if options[:if_exists] == true && !column_exists?(table_name, column_name)

          remove_check_constraints(table_name, column_name)
          remove_default_constraint(table_name, column_name)
          remove_indexes(table_name, column_name)
          execute "ALTER TABLE #{quote_table_name(table_name)} DROP COLUMN #{quote_column_name(column_name)}"
        end

        def drop_table(table_name, options = {})
          # mssql cannot recreate referenced table with force: :cascade
          # https://docs.microsoft.com/en-us/sql/t-sql/statements/drop-table-transact-sql?view=sql-server-2017
          if options[:force] == :cascade
            execute_procedure(:sp_fkeys, pktable_name: table_name).each do |fkdata|
              fktable = fkdata['FKTABLE_NAME']
              fkcolmn = fkdata['FKCOLUMN_NAME']
              pktable = fkdata['PKTABLE_NAME']
              pkcolmn = fkdata['PKCOLUMN_NAME']
              remove_foreign_key(fktable, name: fkdata['FK_NAME'])
              execute("DELETE FROM #{quote_table_name(fktable)} WHERE #{quote_column_name(fkcolmn)} IN ( SELECT #{quote_column_name(pkcolmn)} FROM #{quote_table_name(pktable)} )")
            end
          end

          if options[:if_exists] && mssql_major_version < 13
            # this is for sql server 2012 and 2014
            execute "IF EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = #{quote(table_name)}) DROP TABLE #{quote_table_name(table_name)}"
          else
            # For sql server 2016 onwards
            super
          end
        end

        def rename_table(table_name, new_table_name)
          execute "EXEC sp_rename '#{table_name}', '#{new_table_name}'"
          rename_table_indexes(table_name, new_table_name)
        end

        # This is the same as the abstract method
        def quote_table_name(name)
          quote_column_name(name)
        end

        # This overrides the abstract method to be specific to SQL Server.
        def quote_column_name(name)
          name = name.to_s.split('.')
          name.map! { |n| quote_name_part(n) } # "[#{name}]"
          name.join('.')
        end

        def quote_database_name(name)
          quote_name_part(name.to_s)
        end

        # @private these cannot specify a limit
        NO_LIMIT_TYPES = %i[text binary boolean date].freeze

        # Maps logical Rails types to MSSQL-specific data types.
        def type_to_sql(type, limit: nil, precision: nil, scale: nil, **) # :nodoc:
          # MSSQL's NVARCHAR(n | max) column supports either a number between 1 and
          # 4000, or the word "MAX", which corresponds to 2**30-1 UCS-2 characters.
          #
          # It does not accept NVARCHAR(1073741823) here, so we have to change it
          # to NVARCHAR(MAX), even though they are logically equivalent.
          #
          # See: http://msdn.microsoft.com/en-us/library/ms186939.aspx
          #
          type = type.to_sym if type
          native = native_database_types[type]

          if type == :string && limit == 1_073_741_823
            'nvarchar(max)'
          elsif NO_LIMIT_TYPES.include?(type)
            super(type)
          elsif %i[int integer].include?(type)
            if limit.nil? || limit == 4
              'int'
            elsif limit == 2
              'smallint'
            elsif limit == 1
              'tinyint'
            else
              'bigint'
            end
          elsif type == :uniqueidentifier
            'uniqueidentifier'
          elsif %i[datetime time].include?(type)
            precision ||= 7
            column_type_sql = (native.is_a?(Hash) ? native[:name] : native).dup
            if (0..7).include?(precision)
              column_type_sql << "(#{precision})"
            else
              raise(
                ArgumentError,
                "No #{native[:name]} type has precision of #{precision}. The " \
                'allowed range of precision is from 0 to 7, even though the ' \
                'sql type precision is 7 this adapter will persist up to 6 ' \
                'precision only.'
              )
            end
          else
            super
          end
        end

        # SQL Server requires the ORDER BY columns in the select
        # list for distinct queries, and requires that the ORDER BY
        # include the distinct column.
        def columns_for_distinct(columns, orders) #:nodoc:
          order_columns = orders.reject(&:blank?).map{ |s|
              # Convert Arel node to string
              s = s.to_sql unless s.is_a?(String)
              # Remove any ASC/DESC modifiers
              s.gsub(/\s+(?:ASC|DESC)\b/i, '')
               .gsub(/\s+NULLS\s+(?:FIRST|LAST)\b/i, '')
            }.reject(&:blank?).map.with_index { |column, i| "#{column} AS alias_#{i}" }

          (order_columns << super).join(', ')
        end

        def add_timestamps(table_name, options = {})
          if !options.key?(:precision) && supports_datetime_with_precision?
            options[:precision] = 7
          end

          super
        end

        def create_schema_dumper(options)
          MSSQL::SchemaDumper.create(self, options)
        end

        def rename_column(table_name, column_name, new_column_name)
          # The below line checks if column exists otherwise raise activerecord
          # default exception for this case.
          _column = column_for(table_name, column_name)

          execute "EXEC sp_rename '#{table_name}.#{column_name}', '#{new_column_name}', 'COLUMN'"
          rename_column_indexes(table_name, column_name, new_column_name)
        end

        def change_column_default(table_name, column_name, default_or_changes)
          remove_default_constraint(table_name, column_name)

          default = extract_new_default_value(default_or_changes)
          unless default.nil?
            column = columns(table_name).find { |c| c.name.to_s == column_name.to_s }
            result = execute(
              "ALTER TABLE #{quote_table_name(table_name)} " \
              "ADD CONSTRAINT DF_#{table_name}_#{column_name} " \
              "DEFAULT #{quote_default_expression(default, column)} FOR #{quote_column_name(column_name)}"
            )
            result
          end
        end

        def change_column(table_name, column_name, type, options = {})
          column = columns(table_name).find { |c| c.name.to_s == column_name.to_s }

          indexes = []
          if options_include_default?(options) || (column && column.type != type.to_sym)
            remove_default_constraint(table_name, column_name)
            indexes = indexes(table_name).select{ |index| index.columns.include?(column_name.to_s) }
            remove_indexes(table_name, column_name)
          end

          if !options[:null].nil? && options[:null] == false && !options[:default].nil?
            execute(
              "UPDATE #{quote_table_name(table_name)} SET " \
              "#{quote_column_name(column_name)}=#{quote_default_expression(options[:default], column)} " \
              "WHERE #{quote_column_name(column_name)} IS NULL"
            )
          end

          change_column_type(table_name, column_name, type, options)

          if options_include_default?(options)
            change_column_default(table_name, column_name, options[:default])
          elsif options.key?(:default) && options[:null] == false
            # Drop default constraint when null option is false
            remove_default_constraint(table_name, column_name)
          end

          # add any removed indexes back
          indexes.each do |index|
            index_columns = index.columns.map { |c| quote_column_name(c) }.join(', ')
            execute "CREATE INDEX #{quote_table_name(index.name)} ON #{quote_table_name(table_name)} (#{index_columns})"
          end
        end

        def change_column_null(table_name, column_name, null, default = nil)
          column = column_for(table_name, column_name)
          quoted_table = quote_table_name(table_name)
          quoted_column = quote_column_name(column_name)
          quoted_default = quote(default)
          unless null || default.nil?
            execute("UPDATE #{quoted_table} SET #{quoted_column}=#{quoted_default} WHERE #{quoted_column} IS NULL")
          end
          sql_alter = [
            "ALTER TABLE #{quoted_table}",
            "ALTER COLUMN #{quoted_column} #{type_to_sql(column.type, limit: column.limit, precision: column.precision, scale: column.scale)}",
            (' NOT NULL' unless null)
          ]

          execute(sql_alter.join(' '))
        end

        def update_table_definition(table_name, base) #:nodoc:
          MSSQL::Table.new(table_name, base)
        end

        private

        def schema_creation
          MSSQL::SchemaCreation.new(self)
        end

        def create_table_definition(*args)
          MSSQL::TableDefinition.new(self, *args)
        end

        def new_column_from_field(table_name, field)
          field
        end

        def create_db_edition_options(options = {})
          edition_config = options.select { |k, _v| k.match?('azure') }

          edition_config.each_with_object([]) do |(key, value), output|
            output << case key
                      when :azure_maxsize
                        "MAXSIZE = #{value}"
                      when :azure_edition
                        "EDITION = #{value}"
                      when :service_objective
                        "SERVICE_OBJECTIVE = #{value}"
                      end
          end.compact
        end

        def data_source_sql(name = nil, type: nil)
          scope = quoted_scope(name, type: type)
          table_name = 'TABLE_NAME'

          sql = ''.dup
          sql << "SELECT #{table_name}"
          sql << ' FROM INFORMATION_SCHEMA.TABLES'
          sql << ' WHERE TABLE_CATALOG = DB_NAME()'
          sql << " AND TABLE_SCHEMA = #{quote(scope[:schema])}"
          sql << " AND TABLE_NAME = #{quote(scope[:name])}" if scope[:name]
          sql << " AND TABLE_TYPE = #{quote(scope[:type])}" if scope[:type]
          sql << " ORDER BY #{table_name}"
          sql
        end

        def quoted_scope(raw_name = nil, type: nil)
          schema = ArJdbc::MSSQL::Utils.unqualify_table_schema(raw_name)
          name = ArJdbc::MSSQL::Utils.unqualify_table_name(raw_name)

          scope = {}
          scope[:schema] = schema || 'dbo'
          scope[:name] = name if name
          scope[:type] = type if type
          scope
        end

        def change_column_type(table_name, column_name, type, options = {})
          sql = ''.dup

          sql << "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} #{type_to_sql(type, limit: options[:limit], precision: options[:precision], scale: options[:scale])}"
          sql << (options[:null] ? " NULL" : " NOT NULL") if options.has_key?(:null)
          result = execute(sql)
          result
        end

        # Implements the quoting style for SQL Server
        def quote_name_part(part)
          part =~ /^\[.*\]$/ ? part : "[#{part.gsub(']', ']]')}]"
        end

        def remove_check_constraints(table_name, column_name)
          constraints = select_values "SELECT CONSTRAINT_NAME FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE where TABLE_NAME = '#{quote_string(table_name)}' and COLUMN_NAME = '#{quote_string(column_name)}'", 'SCHEMA'
          constraints.each do |constraint|
            execute "ALTER TABLE #{quote_table_name(table_name)} DROP CONSTRAINT #{quote_column_name(constraint)}"
          end
        end

        def remove_default_constraint(table_name, column_name)
          # If their are foreign keys in this table, we could still get back a 2D array, so flatten just in case.
          execute_procedure(:sp_helpconstraint, table_name, 'nomsg').flatten.select do |row|
            row['constraint_type'] == "DEFAULT on column #{column_name}"
          end.each do |row|
            execute "ALTER TABLE #{quote_table_name(table_name)} DROP CONSTRAINT #{row['constraint_name']}"
          end
        end

        def remove_indexes(table_name, column_name)
          indexes(table_name).select { |index| index.columns.include?(column_name.to_s) }.each do |index|
            remove_index(table_name, name: index.name)
          end
        end

      end
    end
  end
end
