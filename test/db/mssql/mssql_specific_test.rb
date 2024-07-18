require 'db/mssql'

class MSSQLSpecificTest < Test::Unit::TestCase
  MSSQL_VERSIONS = %w[8 9 10 11 12 13 14 15 16].freeze

  def test_mssql_is_implemented_and_returns_true
    conn = ActiveRecord::Base.connection

    assert_respond_to conn, :mssql?
    assert_equal true, conn.mssql?
  end

  def test_mssql_major_version
    conn = ActiveRecord::Base.connection

    mssql_version = conn.mssql_version

    assert_includes MSSQL_VERSIONS, mssql_version.major
  end

  def test_mssql_unsupported_version
    product  = 'Microsoft SQL Server'
    complete = '10.00.4343'
    major    = '10'

    version = [complete, major, nil, nil]

    mssql_version = ActiveRecord::ConnectionAdapters::MSSQL::Version.new(version)
    ActiveRecord::ConnectionAdapters::MSSQLAdapter
      .any_instance.stubs(:mssql_version).returns(mssql_version)

    ActiveRecord::Base.clear_all_connections!

    conn = ActiveRecord::Base.connection

    # conn.stubs(:get_database_version).returns(mssql_version)

    conn.schema_cache.clear!

    binding.irb

    error = assert_raises do
      conn.check_version
    end

    assert_equal "Your #{product} 2008 is too old. This adapter supports #{product} >= 2016.", error.message
  end

  def test_mssql_supported_version
    complete = '11.00.4343'
    major    = '11'

    version = [complete, major, nil, nil]

    mssql_version = ActiveRecord::ConnectionAdapters::MSSQL::Version.new(version)

    ActiveRecord::ConnectionAdapters::MSSQLAdapter
      .any_instance.stubs(:mssql_version).returns(mssql_version)

    ActiveRecord::Base.clear_all_connections!

    assert_nothing_raised do
      ActiveRecord::Base.connection.execute('SELECT 1')
    end

    assert_equal '2012', ActiveRecord::Base.connection.mssql_version.year
  end
end
