# frozen_string_literal: true

module ArJdbc
  module Abstract
    module Quoting

      # Helper to get local/UTC time (based on `ActiveRecord::default_timezone`).
      def time_for_database(value)
        get = ::ActiveRecord.default_timezone == :utc ? :getutc : :getlocal
        value.respond_to?(get) ? value.send(get) : value
      end
    end
  end
end