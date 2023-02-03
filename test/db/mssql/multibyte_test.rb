require 'test_helper'
require 'db/mssql'

class MSSQLMultibyteTest < Test::Unit::TestCase
  include MultibyteTestMethods

  def test_select_multibyte_string
    Entry.create!(:title => 'テスト', :content => '本文')
    entry = Entry.last
    assert_equal "テスト", entry.title
    assert_equal "本文", entry.content
    assert_equal entry, Entry.find_by_title("テスト")
  end

end
