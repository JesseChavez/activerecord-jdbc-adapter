require 'test_helper'
require 'db/mssql'

class MSSQLDateTimeTypesTest < Test::Unit::TestCase

  TABLE_DEFINITION = "CREATE TABLE date_and_times " <<
    "( [id] int NOT NULL IDENTITY(1, 1) PRIMARY KEY, [datetime] DATETIME )"

  @@default_timezone = ActiveRecord.default_timezone

  def self.startup
    super
    ActiveRecord.default_timezone = :local
    ActiveRecord::Base.connection.execute TABLE_DEFINITION
    # ActiveRecord::Base.logger.level = Logger::DEBUG
  end

  def self.shutdown
    # ActiveRecord::Base.logger.level = Logger::WARN
    ActiveRecord::Base.connection.execute "DROP TABLE date_and_times"
    ActiveRecord.default_timezone = @@default_timezone
    super
  end

  class DateAndTime < ActiveRecord::Base; end

  def test_datetime
    # January 1, 1753, through December 31, 9999 + 00:00:00 through 23:59:59.997
    datetime = DateTime.parse('2012-12-21T21:11:01').to_time
    model = DateAndTime.create! :datetime => datetime
    assert_datetime_equal datetime, model.reload.datetime
  end

  def test_datetime_with_zone
    time_zone = false
    default_timezone = ActiveRecord.default_timezone
    ActiveRecord.default_timezone = :local
    time_zone = Time.zone
    Time.zone = 'CET'

    time = Time.local 2013, 8, 14, 11, 45, 58
    model = DateAndTime.create! :datetime => time
    assert_equal time, model.reload.datetime
  ensure
    ActiveRecord.default_timezone = default_timezone
    Time.zone = time_zone unless time_zone == false
  end

  if defined? JRUBY_VERSION && ActiveRecord::Base.connection.sqlserver_version >= '2008'

    # 2008 Date and Time: http://msdn.microsoft.com/en-us/library/ff848733.aspx

    TABLE_DEFINITION.replace "CREATE TABLE date_and_times (" <<
      "[id] int NOT NULL IDENTITY(1, 1)," <<
      "[datetime] DATETIME DEFAULT 0, " <<
      "[date] DATE, " <<
      "[datetime2] DATETIME2, " <<
      "[datetime25] DATETIME2(5), " <<
      "[smalldatetime] SMALLDATETIME, " <<
      "[time] TIME " <<
      " PRIMARY KEY CLUSTERED ( [id] ASC ) WITH ( " <<
       " PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, " <<
       " ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON " <<
      ") ON [PRIMARY] " <<
    ")"

    def test_date
      # 0001-01-01 through 9999-12-31
      date = DateTime.parse('2012-12-31')
      model = DateAndTime.create! :date => date
      assert_instance_of Date, model.reload.date
      assert_date_equal date.to_date, model.date
    end

    def test_datetime2
      # date range + 00:00:00 through 23:59:59.9999999
      with_default_and_local_utc_zone do
        datetime = DateTime.parse('2012-12-21T21:12:03')
        model = DateAndTime.create! :datetime2 => datetime
        assert_datetime_equal datetime, model.reload.datetime2
      end
    end

    def test_datetime25
      datetime = Time.local(1982, 7, 13, 02, 24, 56, 123000)
      model = DateAndTime.create! :datetime25 => datetime
      assert_not_nil model.datetime25
      assert_datetime_equal datetime, model.reload.datetime25
      assert_equal datetime.usec, model.datetime25.usec
    end

    def test_smalldatetime
      # 1900-01-01 through 2079-06-06 + 00:00:00 through 23:59:59
      # with seconds always zero - rounded to the nearest minute
      datetime = DateTime.parse('1999-12-31T23:59:21').to_time
      model = DateAndTime.create! :smalldatetime => datetime
      datetime = DateTime.parse('1999-12-31T23:59:00').to_time
      assert_datetime_equal datetime, model.reload.smalldatetime

      with_default_and_local_utc_zone do
        datetime = DateTime.parse('1999-12-31T22:59:31')
        model = DateAndTime.create! :smalldatetime => datetime
        datetime = DateTime.parse('1999-12-31T23:00:00')
        assert_datetime_equal datetime, model.reload.smalldatetime
      end
    end

    def test_time_usec_in_database
      # 00:00:00.0000000 through 23:59:59.9999999

      sql = "INSERT INTO date_and_times ([time]) VALUES ('22:05:59.123456')"
      id = DateAndTime.connection.insert(sql)

      model = DateAndTime.find(id)
      assert_not_nil model.time
      time = Time.local(2000, 1, 01, 22, 05, 59, 123456)
      assert_time_equal time, model.time
      assert_equal time.usec, model.time.usec
    end

    def test_time_usec_in_ruby
      # 00:00:00.0000000 through 23:59:59.9999999

      time = Time.local(1970, 1, 01, 23, 59, 58, 987543)
      model = DateAndTime.create! :time => time
      assert_not_nil model.time
      assert_time_equal time, model.reload.time
      assert_equal 987543, model.time.usec
    end

    def test_time_usec_in_ruby_edge_case
      # 00:00:00.0000000 through 23:59:59.9999999

      time = Time.local(0000, 1, 01, 23, 59, 58, 987000)
      model = DateAndTime.create! :time => time
      assert_not_nil model.time
      # NOTE: seems to be messed up with PS due a JRuby bug :
      # reports Time instance: '0000-01-01 23:59:58 +0057'
      # ... same mess on MRI :
      # 1.9.3-p551 :004 > Time.local(0000, 1, 01, 23, 59, 0).inspect
      # => "0000-01-01 23:59:00 +0057"
      model.reload
      #pend "TODO:  #{time.inspect} equal #{model.time.inspect}"
      assert_time_equal time, model.time
      assert_equal 987000, model.time.usec
    end

  end

end

