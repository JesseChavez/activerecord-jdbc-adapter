require 'test_helper'
require 'db/mssql'
require 'db/mssql/migration/helper'

module MSSQLMigration
  class ColumnCreationTest < Test::Unit::TestCase
    include TestHelper

    def test_add_column_without_limit
      assert_nothing_raised do
        add_column :entries, :description, :string, limit: nil
      end

      Entry.reset_column_information
      assert_nil Entry.columns_hash['description'].limit
    end

    def test_add_timestamp_with_defaults
      assert_nothing_raised do
        add_timestamps(:reviews)
      end

      Review.reset_column_information
      created_at = Review.columns_hash['created_at']

      assert_equal 'datetime2(7)', created_at.sql_type
      assert_equal nil,            created_at.precision
      assert_equal false,          created_at.null
      assert_equal nil,            created_at.default

      updated_at = Review.columns_hash['updated_at']

      assert_equal 'datetime2(7)', updated_at.sql_type
      assert_equal nil,            updated_at.precision
      assert_equal false,          updated_at.null
      assert_equal nil,            updated_at.default
    end

    def test_add_timestamp_custom
      right_now = Time.now.to_s(:db)
      assert_nothing_raised do
        add_timestamps(:reviews, null: true, precision: 3, default: right_now)
      end

      Review.reset_column_information
      created_at = Review.columns_hash['created_at']

      assert_equal 'datetime2(3)', created_at.sql_type
      assert_equal 3,              created_at.precision
      assert_equal true,           created_at.null
      assert_equal right_now,            created_at.default

      updated_at = Review.columns_hash['updated_at']

      assert_equal 'datetime2(3)', updated_at.sql_type
      assert_equal 3,              updated_at.precision
      assert_equal true,           updated_at.null
      assert_equal right_now,      updated_at.default
    end
  end
end
