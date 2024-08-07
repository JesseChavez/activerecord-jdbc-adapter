# frozen_string_literal: true

require 'active_support/core_ext/string'

module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      # NOTE: the execution plan (explain) is a estimated only for prepared
      # statements similar the jTDS used to provide. The mssql-jdbc driver
      # does not supports explain from prepared statements.
      # more in: https://github.com/Microsoft/mssql-jdbc/issues/778
      #
      module ExplainSupport
        DISABLED = Java::JavaLang::Boolean.getBoolean('arjdbc.mssql.explain_support.disabled')

        def supports_explain?
          !DISABLED
        end

        def explain(arel, binds = [], options = [])
          return if DISABLED

          if arel.respond_to?(:to_sql)
            raw_sql, raw_binds = to_sql_and_binds(arel, binds)
          else
            raw_sql, raw_binds = arel, binds
          end

          # sql = to_sql(arel, binds)
          # result = with_showplan_on { exec_query(sql, 'EXPLAIN', binds) }

          sql = interpolate_sql_statement(raw_sql, raw_binds)

          result = with_showplan_on do
            exec_query(sql, 'EXPLAIN', [])
          end
          PrinterTable.new(result).pp
        end

        protected

        # converting the prepared statements to sql
        def interpolate_sql_statement(arel, binds)
          return arel if binds.empty?

          sql = if arel.respond_to?(:to_sql)
                  arel.to_sql
                else
                  arel
                end

          binds.each do |bind|
            value = quote(bind.value_for_database)
            sql = sql.sub('?', value)
          end

          sql
        end

        def with_showplan_on
          set_showplan_option(true)
          yield
        ensure
          set_showplan_option(false)
        end

        def set_showplan_option(enable = true)
          option = 'SHOWPLAN_ALL'
          execute "SET #{option} #{enable ? 'ON' : 'OFF'}"
        rescue Exception => e
          raise ActiveRecord::ActiveRecordError, "#{option} could not be turned" +
            " #{enable ? 'ON' : 'OFF'} (check SHOWPLAN permissions) due : #{e.inspect}"
        end

        # @private
        class PrinterTable

          cattr_accessor :max_column_width, :cell_padding
          self.max_column_width = 50
          self.cell_padding = 1

          attr_reader :result

          def initialize(result)
            @result = result
          end

          def pp
            @widths = compute_column_widths
            @separator = build_separator
            pp = []
            pp << @separator
            pp << build_cells(result.columns)
            pp << @separator
            result.rows.each do |row|
              pp << build_cells(row)
            end
            pp << @separator
            pp.join("\n") << "\n"
          end

          private

          def compute_column_widths
            [].tap do |computed_widths|
              result.columns.each_with_index do |column, i|
                cells_in_column = [column] + result.rows.map { |r| cast_item(r[i]) }
                computed_width = cells_in_column.map(&:length).max
                final_width = computed_width > max_column_width ? max_column_width : computed_width
                computed_widths << final_width
              end
            end
          end

          def build_separator
            '+'.dup << @widths.map {|w| '-' * (w + (cell_padding * 2))}.join('+') << '+'
          end

          def build_cells(items)
            cells = []
            items.each_with_index do |item, i|
              cells << cast_item(item).ljust(@widths[i])
            end
            "| #{cells.join(' | ')} |"
          end

          def cast_item(item)
            case item
            when NilClass then 'NULL'
            when Float then item.to_s.to(9)
            else item.to_s.truncate(max_column_width)
            end
          end
        end

      end
    end
  end
end
