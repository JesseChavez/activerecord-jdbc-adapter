# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module ColumnMethods
        def primary_key(name, type = :primary_key, **options)
          if [:integer, :bigint].include?(type)
            options[:is_identity] = true unless options.key?(:default)
          end

          super
        end

        # datetime with seconds always zero (:00) and without fractional seconds
        def smalldatetime(*args, **options)
          args.each { |name| column(name, :smalldatetime, options) }
        end

        # this is the old sql server datetime type, the precision is as follow
        # xx1, xx3, and xx7
        def datetime_basic(*args, **options)
          args.each { |name| column(name, :datetime_basic, options) }
        end

        def real(*args, **options)
          args.each { |name| column(name, :real, options) }
        end

        def money(*args, **options)
          args.each { |name| column(name, :money, options) }
        end

        def smallmoney(*args, **options)
          args.each { |name| column(name, :smallmoney, options) }
        end

        def char(*args, **options)
          args.each { |name| column(name, :char, options) }
        end

        def varchar(*args, **options)
          args.each { |name| column(name, :varchar, options) }
        end

        def varchar_max(*args, **options)
          args.each { |name| column(name, :varchar_max, options) }
        end

        def text_basic(*args, **options)
          args.each { |name| column(name, :text_basic, options) }
        end

        def nchar(*args, **options)
          args.each { |name| column(name, :nchar, options) }
        end

        def ntext(*args, **options)
          args.each { |name| column(name, :ntext, options) }
        end

        def binary_basic(*args, **options)
          args.each { |name| column(name, :binary_basic, options) }
        end

        def varbinary(*args, **options)
          args.each { |name| column(name, :varbinary, options) }
        end

        def uuid(*args, **options)
          args.each { |name| column(name, :uniqueidentifier, options) }
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

        def new_column_definition(name, type, **options)
          case type
          when :primary_key
            options[:is_identity] = true
          end

          super
        end

        def timestamps(**options)
          if !options.key?(:precision) && @conn.supports_datetime_with_precision?
            options[:precision] = 7
          end

          super
        end
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods
      end
    end
  end
end
