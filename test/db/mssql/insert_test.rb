require 'test_helper'
require 'db/mssql'

class MSSQLInsertTest < Test::Unit::TestCase
  class CreateInsertEntries < ActiveRecord::Migration[7.0]
    def self.up
      create_table :insert_entries do |t|
        t.column :code, :string, limit: 5
        t.column :notes, :text
        t.column :cookies, :boolean
        t.column :lucky_number, :integer
        t.column :starts, :float
        t.column :total, :decimal, precision: 15, scale: 2
        t.column :date_of_birth, :date
        t.column :expires_at, :datetime
        t.column :start_at, :time
      end
    end

    def self.down
      drop_table :insert_entries
    end
  end

  class InsertEntry < ActiveRecord::Base
  end

  def self.startup
    CreateInsertEntries.up
  end

  def self.shutdown
    CreateInsertEntries.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_create
    data = { code: 'xoxo', total: 5.23, date_of_birth: '2000-12-25' }

    result = InsertEntry.create(data)

    assert_equal 'xoxo', result[:code]
  end

  def test_indentity_insert
    db_conn = InsertEntry.connection

    db_conn.execute("INSERT INTO insert_entries([id], [code]) VALUES (711, 'xoxo')")
  end

  def test_insert
    data = {
      code: 'xoxo', total: 5.23, date_of_birth: '2000-12-25', expires_at: Time.now, start_at: Time.now
    }

    result = InsertEntry.insert!(data, returning: Arel.sql('UPPER(INSERTED.code) as code'))

    assert_equal ['XOXO'], result.pluck('code')
  end

  def test_insert_with_id
    data = { id: 911, code: 'xoxo', total: 5.23, date_of_birth: '2000-12-25'}

    result = InsertEntry.insert!(data, returning: Arel.sql('UPPER(INSERTED.code) as code'))

    assert_equal ['XOXO'], result.pluck('code')
  end

  def test_insert_all
    data = [
      { code: 'one', date_of_birth: '2000-12-25', expires_at: Time.now, start_at: Time.now },
      { code: 'two', date_of_birth: '2000-1-1', expires_at: Time.now, start_at: Time.now }
    ]

    result = InsertEntry.insert_all!(data, returning: %w[code date_of_birth expires_at start_at])

    assert_equal %w[one two], result.pluck('code')
    assert_equal %w[2000-12-25 2000-01-01], result.pluck('date_of_birth').map(&:to_s)
  end
end
