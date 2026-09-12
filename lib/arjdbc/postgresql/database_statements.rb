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

      private

      def perform_query(raw_connection, sql, binds, type_casted_binds, prepare:, notification_payload:, batch:)
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
    end
  end
end
