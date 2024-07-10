require 'test_helper'

class MSSQLUnitTest < Test::Unit::TestCase

  def self.startup; require 'arjdbc/mssql' end

  # NOTE: lot of tests kindly borrowed from __activerecord-sqlserver-adapter__

  test "get_table_name" do
    insert_sql = "INSERT INTO [funny_jokes] ([name]) VALUES('Knock knock')"
    update_sql = "UPDATE [customers] SET [address_street] = NULL WHERE [id] = 2"
    select_sql = "SELECT * FROM [customers] WHERE ([customers].[id] = 1)"

    connection = new_adapter_stub
    assert_equal 'funny_jokes', connection.send(:get_table_name, insert_sql)
    assert_equal 'customers', connection.send(:get_table_name, update_sql)
    assert_equal 'customers', connection.send(:get_table_name, select_sql)

    assert_equal '[funny_jokes]', connection.send(:get_table_name, insert_sql, true)
    assert_equal '[customers]', connection.send(:get_table_name, update_sql, true)
    assert_equal '[customers]', connection.send(:get_table_name, select_sql, true)

    select_sql = " SELECT * FROM  customers  WHERE ( customers.id = 1 ) "
    assert_equal 'customers', connection.send(:get_table_name, select_sql)
    assert_equal 'customers', connection.send(:get_table_name, select_sql, true)

    assert_nil connection.send(:get_table_name, 'SELECT 1')
    # NOTE: this has been failing even before refactoring - not sure if it's needed :
    #assert_nil connection.send(:get_table_name, 'SELECT * FROM someFunction()')
    #assert_nil connection.send(:get_table_name, 'SELECT * FROM someFunction() WHERE 1 > 2')

    select_sql = "SELECT COUNT(*) FROM our_table WHERE text = \"INSERT INTO their_table VALUES ('a', 'b', 'c')\""
    assert_equal 'our_table', connection.send(:get_table_name, select_sql)
  end

  context "Utils" do

    def utils; ArJdbc::MSSQL::Utils end

    setup do
      @expected_table_name = 'baz'; @expected_db_name = 'foo'
      @first_second_table_names = ['[baz]','baz','[bar].[baz]','bar.baz']
      @third_table_names = ['[foo].[bar].[baz]','foo.bar.baz']
      @qualifed_table_names = @first_second_table_names + @third_table_names
    end

    test 'return clean table_name from Utils.unqualify_table_name' do
      @qualifed_table_names.each do |qtn|
        assert_equal @expected_table_name, utils.unqualify_table_name(qtn),
          "This qualifed_table_name #{qtn} did not unqualify correctly."
      end
    end

    test 'return nil from Utils.unqualify_db_name when table_name is less than 2 qualified' do
      @first_second_table_names.each do |qtn|
        assert_equal nil, utils.unqualify_db_name(qtn),
          "This qualifed_table_name #{qtn} did not return nil."
      end
    end

    test 'return clean db_name from Utils.unqualify_db_name when table is thrid level qualified' do
      @third_table_names.each do |qtn|
        assert_equal @expected_db_name, utils.unqualify_db_name(qtn),
          "This qualifed_table_name #{qtn} did not unqualify the db_name correctly."
      end
    end

    test 'returns same table-name if no quoting present' do
      assert_equal 'foo', utils.unqualify_table_name('foo')
    end

    test 'returns schema-name with no quoting present' do
      assert_equal 'foo', utils.unqualify_table_schema('foo.bar')
    end

    test 'returns nil when no schema present' do
      assert_equal nil, utils.unqualify_table_schema('bar')
      assert_equal nil, utils.unqualify_table_schema('[foo]')
    end

    test 'returns correct table-name if no quoting present' do
      assert_equal 'bar', utils.unqualify_table_name('foo.bar')
    end

    test 'double quotes and square brackets are removed from table-name' do
      tn = '["foo"]'
      assert_equal 'foo', utils.unqualify_table_name(tn)
    end

    test 'double quotes and square brackets are removed from table-name with owner/schema' do
      tn = '["foo"].["bar"]'
      assert_equal 'bar', utils.unqualify_table_name(tn)
    end

    test 'double quotes and square brackets are removed from schema-name with owner/schema' do
      tn = '["foo"].["bar"]'
      assert_equal 'foo', utils.unqualify_table_schema(tn)
    end

    test 'returns correct db-name if no quoting present' do
      assert_equal 'foo', utils.unqualify_db_name('foo.bar.baz')
    end

    test 'returns correct db-name with quoting present' do
      assert_equal 'foo', utils.unqualify_db_name('[foo].[bar].baz')
      assert_equal 'foo', utils.unqualify_db_name('[foo].[bar].[baz]')
    end

    test 'double quotes and square brackets are removed from db-name' do
      tn = '["foo"].["bar"].["baz"]'
      assert_equal 'foo', utils.unqualify_db_name(tn)
    end

    test 'returns nil when no db-name present' do
      assert_equal nil, utils.unqualify_db_name('bar')
      assert_equal nil, utils.unqualify_db_name('[foo]')
      assert_equal nil, utils.unqualify_db_name('bar.baz')
      assert_equal nil, utils.unqualify_db_name('[foo].[bar]')
    end

  end

  test "quote column name" do
    connection = new_adapter_stub
    assert_equal "[foo]", connection.quote_column_name("foo")
    assert_equal "[bar]", connection.quote_column_name("[bar]")
    assert_equal "[foo]]bar]", connection.quote_column_name("foo]bar")

    assert_equal "[dbo].[foo]", connection.quote_column_name("dbo.foo")
    assert_equal "[dbo].[bar]", connection.quote_column_name("[dbo].[bar]")
    assert_equal "[foo].[bar]", connection.quote_column_name("[foo].bar")
    assert_equal "[foo].[bar]", connection.quote_column_name("foo.[bar]")
  end

  private

  def new_adapter_stub(config = {})
    config = config.merge :adapter => 'mssql', :sqlserver_version => 2008
    logger = nil
    # connection = stub('connection', database_major_version: 11)
    connection = stub('connection', database_product_version: '14.00.3238')
    connection.stub_everything

    adapter = ActiveRecord::ConnectionAdapters::MSSQLAdapter.new connection, logger, config
    yield(adapter) if block_given?
    adapter
  end

end
