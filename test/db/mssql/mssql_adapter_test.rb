require 'db/mssql'


class MSSQLAdapterTest < Test::Unit::TestCase

  def test_database_exists_returns_false_when_the_database_does_not_exist
    db_name = 'non_extant_database'

    config_part = {
      database: db_name,
      driver:   'com.microsoft.sqlserver.jdbc.SQLServerDriver',
      url:      "jdbc:sqlserver://localhost;databaseName=#{db_name};trustServerCertificate=true;loginTimeout=6"
    }

    config = MSSQL_CONFIG.merge(config_part)

    adapter_class = ActiveRecord::ConnectionAdapters::MSSQLAdapter

    assert_equal adapter_class.database_exists?(config), false, "expected database #{db_name} to not exist"
  end

  def test_database_exists_returns_true_when_the_database_exists
    db_name = MSSQL_CONFIG[:database]

    config_part = {
      database: db_name,
      driver:   'com.microsoft.sqlserver.jdbc.SQLServerDriver',
      url:      "jdbc:sqlserver://localhost;databaseName=#{db_name};trustServerCertificate=true;loginTimeout=6"
    }

    config = MSSQL_CONFIG.merge(config_part)

    adapter_class = ActiveRecord::ConnectionAdapters::MSSQLAdapter

    assert adapter_class.database_exists?(config), "expected database #{db_name} to exist"
  end
end
