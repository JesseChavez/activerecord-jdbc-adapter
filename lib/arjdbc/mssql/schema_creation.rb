# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      class SchemaCreation < SchemaCreation
        private

        def visit_TableDefinition(o)
          if o.as
            table_name = quote_table_name(o.temporary ? "##{o.name}" : o.name)
            query = o.as.respond_to?(:to_sql) ? o.as.to_sql : o.as
            projections, source = query.match(%r{SELECT\s+(.*)?\s+FROM\s+(.*)?}).captures
            select_into = "SELECT #{projections} INTO #{table_name} FROM #{source}"
          else
            # o.instance_variable_set :@as, nil
            # super
            create_sql = +''

            create_sql << "IF NOT EXISTS (SELECT 1 FROM sysobjects WHERE name='#{o.name}' and xtype='U') " if o.if_not_exists
            create_sql << "CREATE#{table_modifier_in_create(o)} TABLE "
            create_sql << "#{quote_table_name(o.name)} "

            statements = o.columns.map { |c| accept c }
            statements << accept(o.primary_keys) if o.primary_keys

            if supports_indexes_in_create?
              statements.concat(o.indexes.map { |column_name, options| index_in_create(o.name, column_name, options) })
            end

            if supports_foreign_keys?
              statements.concat(o.foreign_keys.map { |to_table, options| foreign_key_in_create(o.name, to_table, options) })
            end

            create_sql << "(#{statements.join(', ')})" if statements.present?
            add_table_options!(create_sql, o)
            create_sql
          end
        end

        def add_column_options!(sql, options)
          sql << " DEFAULT #{quote_default_expression(options[:default], options[:column])}" if options_include_default?(options)

          sql << ' NOT NULL' if options[:null] == false

          sql << ' IDENTITY(1,1)' if options[:is_identity] == true

          sql << ' PRIMARY KEY' if options[:primary_key] == true

          sql
        end

        # There is no RESTRICT in MSSQL but it has NO ACTION which behave
        # same as RESTRICT, added this behave according rails api.
        def action_sql(action, dependency)
          case dependency
          when :restrict then "ON #{action} NO ACTION"
          else
            super
          end
        end

      end
    end
  end
end
