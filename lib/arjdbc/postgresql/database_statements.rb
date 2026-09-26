# frozen_string_literal: true

module ArJdbc
  module PostgreSQL
    module DatabaseStatements
      def explain(arel, binds = [], options = [])
        sql    = build_explain_clause(options) + " " + to_sql(arel, binds)

        result = internal_exec_query(sql, "EXPLAIN", binds)
        ActiveRecord::ConnectionAdapters::PostgreSQL::ExplainPrettyPrinter.new.pp(result)
      end

      def build_explain_clause(options = [])
        return "EXPLAIN" if options.empty?

        "EXPLAIN (#{options.join(", ").upcase})"
      end

      # Set when constraints will be checked for the current transaction.
      #
      # Not passing any specific constraint names will set the value for all deferrable constraints.
      #
      # [<tt>deferred</tt>]
      #   Valid values are +:deferred+ or +:immediate+.
      #
      # See https://www.postgresql.org/docs/current/sql-set-constraints.html
      def set_constraints(deferred, *constraints)
        unless %i[deferred immediate].include?(deferred)
          raise ArgumentError, "deferred must be :deferred or :immediate"
        end

        constraints = if constraints.empty?
                        "ALL"
                      else
                        constraints.map { |c| quote_table_name(c) }.join(", ")
                      end
        execute("SET CONSTRAINTS #{constraints} #{deferred.to_s.upcase}")
      end

      private

      def internal_exec_query(sql, name = nil, binds = [], prepare: false, async: false, allow_retry: false, materialize_transactions: true)
          sql = preprocess_query(sql)

        # puts "[1]internal_exec_query----->sql: #{sql}, binds: #{binds}"
        type_casted_binds = type_casted_binds(binds)
        # puts "[2]internal_exec_query----->sql: #{type_casted_binds.size}, binds: #{type_casted_binds}"

        with_raw_connection do |conn|
          if without_prepared_statement?(binds)
            log(sql, name, async: async) { conn.execute_query(sql) }
          else
            log(sql, name, binds, type_casted_binds, async: async) do
              # this is different from normal AR that always caches
              cached_statement = fetch_cached_statement(sql) if prepare && @jdbc_statement_cache_enabled
              conn.execute_prepared_query(sql, type_casted_binds, cached_statement)
            end
          end
        end
      end

      def perform_query(raw_connection, sql, binds, type_casted_binds, prepare:, notification_payload:, batch:)
        # puts "perform_query----->sql: #{sql}, binds: #{binds}"
        result = raw_connection.execute(sql)

        count = 0
        count = result.count if result.respond_to?(:count)

        verified!
        notification_payload[:row_count] = count
        result
      end

      def cast_result(raw_result)
        return ActiveRecord::Result.empty if raw_result.nil?

        fields = raw_result.fields

        if fields.empty?
          ActiveRecord::Result.empty
        else
          ActiveRecord::Result.new(fields, raw_result.values)
        end
      end

      private

      def returning_column_values(result)
        result.rows.first
      end
    end
  end
end
