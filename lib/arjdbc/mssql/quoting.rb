# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Quoting
        extend ActiveSupport::Concern

        QUOTED_COLUMN_NAMES = Concurrent::Map.new # :nodoc:
        QUOTED_TABLE_NAMES = Concurrent::Map.new # :nodoc:

        module ClassMethods # :nodoc:
          def column_name_matcher
            /
              \A
              (
                (?:
                  # \[table_name\].\[column_name\] | function(one or no argument)
                  ((?:\w+\.|\[\w+\]\.)?(?:\w+|\[\w+\])) | \w+\((?:|\g<2>)\)
                )
                (?:\s+AS\s+(?:\w+|\[\w+\]))?
              )
              (?:\s*,\s*\g<1>)*
              \z
            /ix
          end

          def column_name_with_order_matcher
            /
              \A
              (
                (?:
                  # \[table_name\].\[column_name\] | function(one or no argument)
                  ((?:\w+\.|\[\w+\]\.)?(?:\w+|\[\w+\])) | \w+\((?:|\g<2>)\)
                )
                (?:\s+ASC|\s+DESC)?
              )
              (?:\s*,\s*\g<1>)*
              \z
            /ix
          end

          def quote_column_name(name)
            QUOTED_COLUMN_NAMES[name] ||= mssql_quote_column_name(name)
          end

          def quote_table_name(name)
            QUOTED_TABLE_NAMES[name] ||= mssql_quote_column_name(name)
          end

          def mssql_quote_column_name(name)
            name = name.to_s.split(".")
            name.map! { |n| mssql_quote_name_part(n) } # "[#{name}]"
            name.join(".")
          end

          # Implements the quoting style for SQL Server
          def mssql_quote_name_part(part)
            part =~ /^\[.*\]$/ ? part : "[#{part.gsub(']', ']]')}]"
          end
        end

        QUOTED_TRUE  = '1'
        QUOTED_FALSE = '0'

        def quote(value)
          # FIXME: this needs improvements to handle other custom types.
          # Also check if it's possible insert integer into a NVARCHAR
          case value
          when ActiveRecord::Type::Binary::Data
            "0x#{value.hex}"
          # when SomeOtherBinaryData then BLOB_VALUE_MARKER
          # when SomeOtherData then "yyy"
          when String, ActiveSupport::Multibyte::Chars
            "N'#{quote_string(value)}'"
          # when OnlyTimeType then "'#{quoted_time(value)}'"
          when Date, Time
            "'#{quoted_date(value)}'"
          when TrueClass
            quoted_true
          when FalseClass
            quoted_false
          else
            super
          end
        end

        # Quote date/time values for use in SQL input, includes microseconds
        # with three digits only if the value is a Time responding to usec.
        # The JDBC drivers does not work with 6 digits microseconds
        def quoted_date(value)
          if value.acts_like?(:time)
            value = time_with_db_timezone(value)
          end

          result = value.to_fs(:db)

          if value.respond_to?(:usec) && value.usec > 0
            "#{result}.#{sprintf("%06d", value.usec)}"
          else
            result
          end
        end

        # Quotes strings for use in SQL input.
        def quote_string(s)
          s.to_s.gsub(/\'/, "''")
        end

        # Does not quote function default values for UUID columns
        def quote_default_expression(value, column)
          cast_type = lookup_cast_type(column.sql_type)
          if cast_type.type == :uuid && value =~ /\(\)/
            value
          elsif column.type == :datetime_basic && value.is_a?(String)
            # let's trust the user to set a right default value for this
            # legacy type something like: '2017-02-28 01:59:19.789'
            quote(value)
          else
            super
          end
        end

        def quoted_true
          QUOTED_TRUE
        end

        def quoted_false
          QUOTED_FALSE
        end

        # @override
        def quoted_time(value)
          if value.acts_like?(:time)
            tz_value = time_with_db_timezone(value)
            usec = value.respond_to?(:usec) ? value.usec : 0
            sprintf('%02d:%02d:%02d.%06d', tz_value.hour, tz_value.min, tz_value.sec, usec)
          else
            quoted_date(value)
          end
        end

        # @private
        # @see #quote in old adapter
        BLOB_VALUE_MARKER = "''"

        private

        def time_with_db_timezone(value)
          zone_conv_method = if ActiveRecord.default_timezone == :utc
                               :getutc
                             else
                               :getlocal
                             end

          if value.respond_to?(zone_conv_method)
            value = value.send(zone_conv_method)
          else
            value
          end
        end
      end
    end
  end
end
