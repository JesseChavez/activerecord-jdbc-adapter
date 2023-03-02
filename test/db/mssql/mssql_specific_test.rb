require 'db/mssql'

class MSSQLSpecificTest < Test::Unit::TestCase
  MSSQL_VERSIONS = [8, 9, 10, 11, 12, 13, 14, 15, 16].freeze

  def test_mssql_is_implemented_and_returns_true
    conn = ActiveRecord::Base.connection

    assert_respond_to conn, :mssql?
    assert_equal true, conn.mssql?
  end

  def test_mssql_major_version
    conn = ActiveRecord::Base.connection

    assert_includes MSSQL_VERSIONS, conn.mssql_major_version
  end

  def test_mssql_unsupported_version
    product_name = 'Microsoft SQL Server'
    product_version = '10.00.4343'
    major_version = 10

    ActiveRecord::ConnectionAdapters::MSSQLAdapter
      .any_instance.stubs(:mssql_product_version).returns(product_version)

    ActiveRecord::ConnectionAdapters::MSSQLAdapter
      .any_instance.stubs(:mssql_product_name).returns(product_name)

    ActiveRecord::ConnectionAdapters::MSSQLAdapter
      .any_instance.stubs(:mssql_major_version).returns(major_version)

    ActiveRecord::Base.clear_all_connections!

    error = assert_raises do
      ActiveRecord::Base.connection.execute('SELECT 1')
    end

    assert_equal "Your #{product_name} 2008 is too old. This adapter supports #{product_name} >= 2012.", error.message
  end

  def test_mssql_supported_version
    ActiveRecord::ConnectionAdapters::MSSQLAdapter
      .any_instance.stubs(:mssql_major_version).returns(11)

    ActiveRecord::Base.clear_all_connections!

    assert_nothing_raised do
      ActiveRecord::Base.connection.execute('SELECT 1')
    end

    assert_equal '2012', ActiveRecord::Base.connection.mssql_version_year
  end
end
