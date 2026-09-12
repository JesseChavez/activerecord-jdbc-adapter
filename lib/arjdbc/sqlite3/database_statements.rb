# frozen_string_literal: true

module ArJdbc
  module SQLite3
    module DatabaseStatements
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

        raw_result
      end
    end
  end
end
