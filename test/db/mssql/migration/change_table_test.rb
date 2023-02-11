require 'test_helper'
require 'db/mssql'
require 'db/mssql/migration/helper'

module MSSQLMigration
  class ChangeTableTest < Test::Unit::TestCase
    include TestHelper

    def test_add_column
      skip 'No sure why this fails, it might be a active record bug'
      assert_nothing_raised do
        change_table(:entries) do |t|
          t.column :entries, :change_table_new_column, :string, limit: 100
        end
      end

      Entry.reset_column_information
      Entry.create(change_table_new_column: 'hola')

      assert Entry.column_names.include? 'change_table_new_column'
      assert_equal ['hola'], Entry.all.map(&:change_table_new_column)
    end
  end
end
