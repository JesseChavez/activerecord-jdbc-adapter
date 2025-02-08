# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    # MSSQL specific extensions to column definitions in a table.
    class MSSQLColumn < Column
      attr_reader :table_name

      def initialize(name, raw_default, sql_type_metadata = nil, null = true, table_name = nil, default_function = nil, collation = nil, comment: nil)
        @table_name = table_name

        default_val, default_fun = extract_default(raw_default)

        super(name, default_val, sql_type_metadata, null, default_fun, collation: collation, comment: comment)
      end

      def extract_default(value)
        return [nil, nil] unless value

        case value
        when /\A\(N?'(.*)'\)\Z/m
          [unquote_string(Regexp.last_match[1]), nil]
        when /\A\(\((.*)\)\)\Z/
          [unquote_string(Regexp.last_match[1]), nil]
        when /\A\((\w+\(\))\)\Z/
          [nil, unquote_string(Regexp.last_match[1])]
        else
          # return nil if default does not match the patterns to avoid
          # any unexpected errors.
          [nil, nil]
        end
      end

      def unquote_string(string)
        string.to_s.gsub("''", "'")
      end

      def identity?
        sql_type.downcase.include? 'identity'
      end
      alias_method :auto_incremented_by_db?, :identity?

      def ==(other)
        other.is_a?(MSSQLColumn) &&
          super &&
          table_name == other.table_name
      end
      alias :eql? :==

      def hash
        MSSQLColumn.hash ^
          super.hash ^
          table_name.hash
      end
    end
  end
end
