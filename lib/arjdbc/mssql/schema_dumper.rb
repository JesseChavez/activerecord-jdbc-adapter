# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      class SchemaDumper < ConnectionAdapters::SchemaDumper
        MSSQL_NO_LIMIT_TYPES = [
          'text',
          'ntext',
          'varchar(max)',
          'nvarchar(max)',
          'varbinary(max)'
        ].freeze

        private

        def schema_limit(column)
          return if MSSQL_NO_LIMIT_TYPES.include?(column.sql_type)

          super
        end

        def explicit_primary_key_default?(column)
          !column.identity?
        end

        def default_primary_key?(column)
          super && column.identity?
        end

        # def schema_collation(column)
        #   return unless column.collation
        #   column.collation if column.collation != collation
        # end

      end
    end
  end
end
