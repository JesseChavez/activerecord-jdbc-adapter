# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    # MSSQL specific extensions to column definitions in a table.
    class MSSQLColumn < Column
      attr_reader :table_name

      def initialize(name, raw_default, sql_type_metadata = nil, null = true, table_name = nil, default_function = nil, collation = nil, comment: nil)
        @table_name = table_name

        default = extract_default(raw_default)

        super(name, default, sql_type_metadata, null, default_function, collation: collation, comment: comment)
      end

      def extract_default(value)
        # return nil if default does not match the patterns to avoid
        # any unexpected errors.
        return unless value =~ /^\(N?'(.*)'\)$/m || value =~ /^\(\(?(.*?)\)?\)$/

        unquote_string(Regexp.last_match[1])
      end

      def unquote_string(string)
        string.to_s.gsub("''", "'")
      end

      def identity?
        sql_type.downcase.include? 'identity'
      end

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
