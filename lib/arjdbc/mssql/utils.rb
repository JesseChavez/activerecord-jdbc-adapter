# frozen_string_literal: true

# NOTE: file contains code adapted from **sqlserver** adapter, license follows
=begin
Copyright (c) 2008-2015

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end

module ArJdbc
  module MSSQL
    module Utils
      TABLE_NAME_INSERT_UPDATE = /^\s*(INSERT|EXEC sp_executesql N'INSERT)(?:\s+INTO)?\s+([^\(\s]+)\s*|^\s*update\s+([^\(\s]+)\s*/i

      TABLE_NAME_FROM = /\bFROM\s+([^\(\)\s,]+)\s*/i

      def self.insert_sql?(sql)
        !(sql =~ /^\s*(INSERT|EXEC sp_executesql N'INSERT)/i).nil?
      end

      def self.get_table_name(sql, qualified = nil)
        if sql =~ TABLE_NAME_INSERT_UPDATE
          tn = $2 || $3
          qualified ? tn : unqualify_table_name(tn)
        elsif sql =~ TABLE_NAME_FROM
          qualified ? $1 : unqualify_table_name($1)
        end
      end

      def self.unquote_table_name(table_name)
        remove_identifier_delimiters(table_name)
      end

      def self.unquote_column_name(column_name)
        remove_identifier_delimiters(column_name)
      end

      def self.unquote_string(string)
        string.to_s.gsub("''", "'")
      end

      def self.unqualify_table_name(table_name)
        return if table_name.blank?

        remove_identifier_delimiters(table_name.to_s.split('.').last)
      end

      def self.unqualify_table_schema(table_name)
        schema_name = table_name.to_s.split('.')[-2]
        schema_name.nil? ? nil : remove_identifier_delimiters(schema_name)
      end

      def self.unqualify_db_name(table_name)
        table_names = table_name.to_s.split('.')
        table_names.length == 3 ? remove_identifier_delimiters(table_names.first) : nil
      end

      # private

      # See "Delimited Identifiers": http://msdn.microsoft.com/en-us/library/ms176027.aspx
      def self.remove_identifier_delimiters(keyword)
        keyword.to_s.tr("\]\[\"", '')
      end
    end
  end
end
