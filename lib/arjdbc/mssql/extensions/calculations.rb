# frozen_string_literal: true

require 'active_record/relation'
require 'active_record/version'

# NOTE: some improvements in active record  broke sql calculations and habtm
# associations for this adapter and the supporting arel visitor.
# this extension fixes this issue in rails 5.1.4 onwards
#
# https://github.com/rails/rails/pull/29848
# https://github.com/rails/rails/pull/30686

module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Calculations
        private

        def build_count_subquery(relation, column_name, distinct)
          super(relation.unscope(:order), column_name, distinct)
        end

      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  mod = ActiveRecord::ConnectionAdapters::MSSQL::Calculations
  ActiveRecord::Relation.prepend(mod)
end
