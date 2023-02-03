require 'test_helper'
require 'db/mssql'

class MSSQLColumnExactNumericTypesTest < Test::Unit::TestCase
  # NOTE: This specs change the behaviour of the previous versions (Rails 5.x)
  # where the default value gets send to database as the user defined.
  # In this versions (Rails 6.0) we adopt the ActiveRecord default behaviour
  # so the default will be casted as per column definition.

  class CreateExactNumericTypes < ActiveRecord::Migration[6.0]
    def self.up
      create_table 'exact_numeric_types', force: true do |t|
        t.column :my_decimal, :decimal
        t.column :decimal_one, :decimal, precision: 15, default:  9.11
        t.column :decimal_two, :decimal, precision: 15, scale: 2, default: 7.11,  null: false
        t.column :decimal_rounded, :decimal, precision: 15, scale: 3, default: 54534.6785,  null: false
        t.column :decimal_unrounded, :decimal, precision: 15, scale: 3, default: 54534.2344,  null: false
        t.column :my_money, :money, null: false, default: 54534.67899
        t.column :my_smallmoney, :smallmoney, null: false, default: 54534.67899
      end

      execute 'ALTER TABLE exact_numeric_types ADD decimal_alt NUMERIC(10,4)'
    end

    def self.down
      drop_table 'exact_numeric_types'
    end
  end

  class ExactNumericTypes < ActiveRecord::Base
    self.table_name = 'exact_numeric_types'
  end

  def self.startup
    CreateExactNumericTypes.up
  end

  def self.shutdown
    CreateExactNumericTypes.down
    ActiveRecord::Base.clear_active_connections!
  end

  Type = ActiveRecord::ConnectionAdapters::MSSQL::Type

  def test_decimal_with_defaults
    # When precision  and scale are not provided SQL Server will use
    # its own defaults:
    #   precision: 18
    #   scale: 0
    #
    column = ExactNumericTypes.columns_hash['my_decimal']

    assert_equal :decimal,        column.type
    assert_equal true,            column.null
    assert_equal nil,             column.default
    assert_equal 'decimal(18,0)', column.sql_type
    assert_equal 18,              column.precision
    assert_equal nil,             column.scale

    type = ExactNumericTypes.connection.send(:type_map).lookup(column.sql_type)
    assert_instance_of Type::DecimalWithoutScale, type
  end

  def test_decimal_with_precison_and_default
    # default value is casted according the column type in this case
    # DecimalWithoutScale which is an Integer
    #
    column = ExactNumericTypes.columns_hash['decimal_one']

    assert_equal :decimal,        column.type
    assert_equal true,            column.null
    assert_equal '9',             column.default
    assert_equal 'decimal(15,0)', column.sql_type
    assert_equal 15,              column.precision
    assert_equal nil,             column.scale

    type = ExactNumericTypes.connection.send(:type_map).lookup(column.sql_type)
    assert_instance_of Type::DecimalWithoutScale, type
  end

  def test_decimal_with_precison_scale_default_and_not_null
    column = ExactNumericTypes.columns_hash['decimal_two']

    assert_equal :decimal,        column.type
    assert_equal false,           column.null
    assert_equal '7.11',          column.default
    assert_equal 'decimal(15,2)', column.sql_type
    assert_equal 15,              column.precision
    assert_equal 2,               column.scale

    type = ExactNumericTypes.connection.send(:type_map).lookup(column.sql_type)
    assert_instance_of Type::Decimal, type
  end

  def test_decimal_with_precison_scale_not_null_default_rounded
    column = ExactNumericTypes.columns_hash['decimal_rounded']

    assert_equal :decimal,        column.type
    assert_equal false,           column.null
    assert_equal '54534.679',     column.default
    assert_equal 'decimal(15,3)', column.sql_type
    assert_equal 15,              column.precision
    assert_equal 3,               column.scale

    type = ExactNumericTypes.connection.send(:type_map).lookup(column.sql_type)
    assert_instance_of Type::Decimal, type
  end

  def test_decimal_with_precison_scale_not_null_default_unrounded
    column = ExactNumericTypes.columns_hash['decimal_unrounded']

    assert_equal :decimal,        column.type
    assert_equal false,           column.null
    assert_equal '54534.234',     column.default
    assert_equal 'decimal(15,3)', column.sql_type
    assert_equal 15,              column.precision
    assert_equal 3,               column.scale

    type = ExactNumericTypes.connection.send(:type_map).lookup(column.sql_type)
    assert_instance_of Type::Decimal, type
  end

  def test_numeric
    column = ExactNumericTypes.columns_hash['decimal_alt']

    assert_equal :decimal,        column.type
    assert_equal true,            column.null
    assert_equal nil,             column.default
    assert_equal 'numeric(10,4)', column.sql_type
    assert_equal 10,              column.precision
    assert_equal 4,               column.scale

    type = ExactNumericTypes.connection.send(:type_map).lookup(column.sql_type)
    assert_instance_of Type::Decimal, type
  end

  def test_money
    column = ExactNumericTypes.columns_hash['my_money']

    # NOTE: here the 4 decimal digit is rounded but because is 9
    # becomes 0 and carries 1 to the 3 decimal digit  resulting.
    # 54534.67899 becomes 54534.679

    assert_equal :money,        column.type
    assert_equal false,         column.null
    assert_equal '54534.679',   column.default
    assert_equal 'money',       column.sql_type
    assert_equal 19,            column.precision
    assert_equal 4,             column.scale

    type = ExactNumericTypes.connection.send(:type_map).lookup(column.sql_type)
    assert_instance_of Type::Money, type
  end

  def test_smallmoney
    column = ExactNumericTypes.columns_hash['my_smallmoney']

    assert_equal :smallmoney,   column.type
    assert_equal false,         column.null
    assert_equal '54534.679',   column.default
    assert_equal 'smallmoney',  column.sql_type
    assert_equal 10,            column.precision
    assert_equal 4,             column.scale

    type = ExactNumericTypes.connection.send(:type_map).lookup(column.sql_type)
    assert_instance_of Type::SmallMoney, type
  end

  def test_decimal_aliases
    assert_cast_type :decimal, 'DECIMAL'
    assert_cast_type :decimal, 'NUMERIC'
    assert_cast_type :decimal, 'number'
    assert_cast_type :decimal, 'NUMBER'
    assert_cast_type :money,   'MONEY'
    assert_cast_type :smallmoney, 'SMALLMONEY'
  end

  private

  def assert_cast_type(type, sql_type)
    cast_type = ExactNumericTypes.connection.send(:type_map).lookup(sql_type)
    assert_equal type, cast_type.type
  end
end
