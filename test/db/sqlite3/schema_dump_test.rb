require 'db/sqlite3'
require 'schema_dump'

class SQLite3SchemaDumpTest < Test::Unit::TestCase
  include SchemaDumpTestMethods

  def test_excludes_sqlite_sequence
    output = standard_dump
    assert_no_match %r{create_table "sqlite_sequence"}, output
  end

  def test_dumping_with_dot_in_table_name
    pend 'in Rails 6, a.b means database table "b" in database "a". Delete test?'

    connection.create_table('test.some_records') { |t| t.string :name }
    connection.add_index('test.some_records', :name, :unique => true)
    assert_equal 2, connection.columns('test.some_records').size
    assert_equal 1, connection.indexes('test.some_records').size
    begin
      output = standard_dump
      assert_match %r{create_table "test.some_records"}, output
      assert_match %r{test.some_records_on_name}, output   # index line
    ensure
      ActiveRecord::Base.connection.drop_table('test.some_records')
    end
  end

end
