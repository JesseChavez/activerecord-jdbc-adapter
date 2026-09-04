# frozen_string_literal: true

# Everything here is mostly to help with the rails test suite, and all come from PG native code.
# They aren't really meant to be used by user code, but without them a number of tests outright fail.
module PG
  CONNECTION_OK = 0 unless const_defined?(:CONNECTION_OK)
  CONNECTION_BAD = 1 unless const_defined?(:CONNECTION_BAD)

  PQTRANS_IDLE = 0 unless const_defined?(:PQTRANS_IDLE)
  PQTRANS_ACTIVE = 1 unless const_defined?(:PQTRANS_ACTIVE)
  PQTRANS_INTRANS = 2 unless const_defined?(:PQTRANS_INTRANS)
  PQTRANS_INERROR = 3 unless const_defined?(:PQTRANS_INERROR)
  PQTRANS_UNKNOWN = 4 unless const_defined?(:PQTRANS_UNKNOWN)
end

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLJdbcConnection
      def status
        really_valid? ? ::PG::CONNECTION_OK : ::PG::CONNECTION_BAD
      end

      def transaction_status
        jdbc_connection.auto_commit ? ::PG::PQTRANS_IDLE : ::PG::PQTRANS_INTRANS
      end

      alias_method :async_exec, :execute
    end
  end
end
