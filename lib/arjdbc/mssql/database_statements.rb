# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module DatabaseStatements
        def exec_proc(proc_name, *variables)
          vars =
            if variables.any? && variables.first.is_a?(Hash)
              variables.first.map { |k, v| "@#{k} = #{quote(v)}" }
            else
              variables.map { |v| quote(v) }
            end.join(', ')
          sql = "EXEC #{proc_name} #{vars}".strip
          log(sql, 'Execute Procedure') do
            result = @connection.execute_query_raw(sql)
            result.map! do |row|
              row = row.is_a?(Hash) ? row.with_indifferent_access : row
              yield(row) if block_given?
              row
            end
            result
          end
        end
        alias_method :execute_procedure, :exec_proc # AR-SQLServer-Adapter naming

        READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
          :begin, :commit, :explain, :select, :set, :show, :release, :savepoint, :rollback, :with
        ) # :nodoc:
        private_constant :READ_QUERY

        def write_query?(sql) # :nodoc:
          !READ_QUERY.match?(sql)
        end

        def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil)
          table_name_for_identity_insert = identity_insert_table_name(sql)

          if table_name_for_identity_insert
            with_identity_insert_enabled(table_name_for_identity_insert) do
              super
            end
          else
            super
          end
        end

        # Internal method to test different isolation levels supported by this
        # mssql adapter. NOTE: not a active record method
        def supports_transaction_isolation_level?(level)
          raw_jdbc_connection.supports_transaction_isolation?(level)
        end

        # Internal method to test different isolation levels supported by this
        # mssql adapter. Not a active record method
        def transaction_isolation=(value)
          raw_jdbc_connection.set_transaction_isolation(value)
        end

        # Internal method to test different isolation levels supported by this
        # mssql adapter. Not a active record method
        def transaction_isolation
          raw_jdbc_connection.get_transaction_isolation
        end

        def insert_fixtures_set(fixture_set, tables_to_delete = [])
          fixture_inserts = []

          fixture_set.each do |table_name, fixtures|
            fixtures.each_slice(insert_rows_length) do |batch|
              fixture_inserts << build_fixture_sql(batch, table_name)
            end
          end

          table_deletes = tables_to_delete.map do |table|
            "DELETE FROM #{quote_table_name(table)}".dup
          end
          total_sql = Array.wrap(combine_multi_statements(table_deletes + fixture_inserts))

          disable_referential_integrity do
            transaction(requires_new: true) do
              total_sql.each do |sql|
                execute sql, 'Fixtures Load'
                yield if block_given?
              end
            end
          end
        end

        # Implements the truncate method.
        def truncate(table_name, name = nil)
          execute "TRUNCATE TABLE #{quote_table_name(table_name)}", name
        end

        def truncate_tables(*table_names) # :nodoc:
          return if table_names.empty?

          disable_referential_integrity do
            table_names.each do |table_name|
              mssql_truncate(table_name)
            end
          end
        end

        def internal_exec_query(sql, name = 'SQL', binds = [], prepare: false, async: false)
          sql = transform_query(sql)

          check_if_write_query(sql)

          mark_transaction_written_if_write(sql)

          # binds = convert_legacy_binds_to_attributes(binds) if binds.first.is_a?(Array)

          if without_prepared_statement?(binds)
            log(sql, name) do
              with_raw_connection do |conn|
                result = conn.execute_query(sql)
                verified!
                result
              end
            end
          else
            log(sql, name, binds) do
              with_raw_connection do |conn|
                # this is different from normal AR that always caches
                cached_statement = fetch_cached_statement(sql) if prepare && @jdbc_statement_cache_enabled
                result = conn.execute_prepared_query(sql, binds, cached_statement)
                verified!
                result
              end
            end
          end
        end

        private

        def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: true)
          log(sql, name, async: async) do
            with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
              result = conn.execute(sql)
              verified!
              result
            end
          end
        end

        def raw_jdbc_connection
          @raw_connection
        end

        # It seems the truncate_tables is mostly used for testing
        # this a workaround to the fact that SQL Server truncate tables
        # referenced by a foreign key, it may not be required to reset
        # the identity column too, more at:
        #    https://docs.microsoft.com/en-us/sql/t-sql/statements/truncate-table-transact-sql?view=sql-server-ver15
        # TODO: improve is with pure T-SQL, use statements
        # such as TRY CATCH and reset identity with DBCC CHECKIDENT
        def mssql_truncate(table_name)
          execute "TRUNCATE TABLE #{quote_table_name(table_name)}", 'Truncate Tables'
        rescue => e
          if e.message =~ /Cannot truncate table .* because it is being referenced by a FOREIGN KEY constraint/
          execute "DELETE FROM #{quote_table_name(table_name)}", 'Truncate Tables with Delete'
          else
            raise
          end
        end

        # Overrides method in abstract class, combining the sqls with semicolon
        # affects disable_referential_integrity in mssql specially when multiple
        # tables are involved.
        def combine_multi_statements(total_sql)
          total_sql
        end

        def default_insert_value(column)
          if column.identity?
            table_name = quote(quote_table_name(column.table_name))
            Arel.sql("IDENT_CURRENT(#{table_name}) + IDENT_INCR(#{table_name})")
          else
            super
          end
        end

        def insert_sql?(sql)
          !(sql =~ /^\s*(INSERT|EXEC sp_executesql N'INSERT)/i).nil? 
        end

        def identity_insert_table_name(sql)
          table_name = get_table_name(sql)
          id_column = identity_column_name(table_name)
          if id_column && sql.strip =~ /INSERT INTO [^ ]+ ?\((.+?)\)/i
            insert_columns = $1.split(/, */).map{|w| ArJdbc::MSSQL::Utils.unquote_column_name(w)}
            return table_name if insert_columns.include?(id_column)
          end
        end

        def identity_column_name(table_name)
          for column in schema_cache.columns(table_name)
            return column.name if column.identity?
          end
          nil
        end

        # Turns IDENTITY_INSERT ON for table during execution of the block
        # N.B. This sets the state of IDENTITY_INSERT to OFF after the
        # block has been executed without regard to its previous state
        def with_identity_insert_enabled(table_name)
          set_identity_insert(table_name, true)
          yield
        ensure
          set_identity_insert(table_name, false)
        end

        def set_identity_insert(table_name, enable = true)
          if enable
            execute("SET IDENTITY_INSERT #{quote_table_name(table_name)} ON")
          else
            execute("SET IDENTITY_INSERT #{quote_table_name(table_name)} OFF")
          end
        rescue Exception => e
          raise ActiveRecord::ActiveRecordError, "IDENTITY_INSERT could not be turned" +
                " #{enable ? 'ON' : 'OFF'} for table #{table_name} due : #{e.inspect}"
        end

        def get_table_name(sql, qualified = nil)
          if sql =~ TABLE_NAME_INSERT_UPDATE
            tn = $2 || $3
            qualified ? tn : ArJdbc::MSSQL::Utils.unqualify_table_name(tn)
          elsif sql =~ TABLE_NAME_FROM
            qualified ? $1 : ArJdbc::MSSQL::Utils.unqualify_table_name($1)
          else
            nil
          end
        end

        TABLE_NAME_INSERT_UPDATE = /^\s*(INSERT|EXEC sp_executesql N'INSERT)(?:\s+INTO)?\s+([^\(\s]+)\s*|^\s*update\s+([^\(\s]+)\s*/i

        TABLE_NAME_FROM = /\bFROM\s+([^\(\)\s,]+)\s*/i
      end
    end
  end
end
