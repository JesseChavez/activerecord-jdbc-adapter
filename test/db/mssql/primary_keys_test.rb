require 'test_helper'
require 'db/mssql'

class MSSQLColumnPrimaryKeysTest < Test::Unit::TestCase
  class CreatePrimaryKeysTests < ActiveRecord::Migration[6.0]
    def self.up
      create_table :primary_keys_tests, force: true, id: false do |t|
        t.string :custom_id
        t.string :content
      end
    end

    def self.down
      drop_table :primary_keys_tests
    end
  end

  class PrimaryKeysTest < ActiveRecord::Base
    self.primary_key = :custom_id
  end

  def self.startup
    CreatePrimaryKeysTests.up
  end

  def self.shutdown
    CreatePrimaryKeysTests.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_custom_primary_key
    record = PrimaryKeysTest.create!(custom_id: '666')

    record.id = '711'
    record.save!

    record = PrimaryKeysTest.first
    assert_equal '711', record.id
  end

  def test_schema_dump_primary_key_integer_with_default_nil
    conn = ActiveRecord::Base.connection
    conn.create_table(:int_defaults, id: :integer, default: nil, force: true)
    schema = dump_table_schema 'int_defaults'

    assert_match %r{create_table "int_defaults", id: :integer, default: nil}, schema
  end

  def test_schema_dump_primary_key_bigint_with_default_nil
    conn = ActiveRecord::Base.connection
    conn.create_table(:bigint_defaults, id: :bigint, default: nil, force: true)
    schema = dump_table_schema 'bigint_defaults'

    assert_match %r{create_table "bigint_defaults", id: :bigint, default: nil}, schema
  end

  private

  def dump_table_schema(table)
    all_tables = ActiveRecord::Base.connection.tables
    ActiveRecord::SchemaDumper.ignore_tables = all_tables - [table]
    stream = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    stream.string
  end
end
