require 'db/mssql'


class MSSQLAdapterTest < Test::Unit::TestCase

  def test_database_exists_returns_false_when_the_database_does_not_exist
    config = MSSQL_CONFIG.merge({ database: 'non_extant_database', adapter: 'sqlserver'})

    assert_equal ActiveRecord::ConnectionAdapters::MSSQLAdapter.database_exists?(config),
      false, "expected database #{config[:database]} to not exist"
  end

  def test_database_exists_returns_true_when_the_database_exists
    config = MSSQL_CONFIG

    assert ActiveRecord::ConnectionAdapters::MSSQLAdapter.database_exists?(config),
      "expected database #{config[:database]} to exist"
  end
end
