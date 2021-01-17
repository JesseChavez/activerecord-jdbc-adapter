require 'rake_test_support'
require 'db/mssql'

class MSSQLRakeDbCreateTest < Test::Unit::TestCase
  include RakeTestSupport

  def db_config
    MSSQL_CONFIG
  end

  def do_teardown
    drop_rake_test_database(:silence)
  end

  test 'rake db:create (and db:drop)' do
    begin
      Rake::Task["db:create"].invoke
    rescue => e
      if e.message =~ /CREATE DATABASE permission denied/
        puts "\nwarning: db:create test skipped; add 'dbcreator' role to user '#{db_config[:username]}' to run"
        return
      end
    end

    ActiveRecord::Base.establish_connection(db_config.merge(:database => "master"))
    assert_include databases, db_name

    Rake::Task["db:drop"].invoke

    ActiveRecord::Base.establish_connection(db_config.merge(:database => "master"))
    assert_not_include databases, db_name
  end

  test 'rake db:drop (non-existing database)' do
    drop_rake_test_database(:silence)

    # Im assuming this test is here to check that we
    # blow up when droping non-existent db
    begin
      Rake::Task["db:drop"].invoke
    rescue => e
      raise e unless e.message =~ /Cannot open database "#{Regexp.quote(db_name)}" requested by the login/
    end
  end

  test 'rake db:test:purge' do
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      connection.create_table('rake_users') { |t| t.string :name }
    end

    Rake::Task["db:test:purge"].invoke

    ActiveRecord::Base.establish_connection db_config.merge :database => db_name
    assert_false ActiveRecord::Base.connection.table_exists?('rake_users')
    ActiveRecord::Base.connection.disconnect!
  end

  test 'rake db:structure:dump (and db:structure:load)' do
    omit('smoscript not available') unless self.class.which('smoscript')
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      create_schema_migrations_table(connection)
      connection.create_table('rake_users') { |t| t.string :name; t.timestamps }
    end

    structure_sql = File.join('db', structure_sql_filename)
    begin
      Dir.mkdir 'db' # db/structure.sql
      Rake::Task["db:structure:dump"].invoke

      assert File.exists?(structure_sql)
      # CREATE TABLE [dbo].[rake_users]( ... )
      assert_match(/CREATE TABLE .*?\[rake_users\]/i, File.read(structure_sql))

      # db:structure:load
      drop_rake_test_database(:silence)
      create_rake_test_database
      Rake::Task["db:structure:load"].invoke

      ActiveRecord::Base.establish_connection db_config.merge :database => db_name
      assert ActiveRecord::Base.connection.table_exists?('rake_users')
      ActiveRecord::Base.connection.disconnect!
    ensure
      File.delete(structure_sql) if File.exists?(structure_sql)
      Dir.rmdir 'db'
    end
  end

  setup { rm_r 'db' if File.exist?('db') }

  test 'rake db:charset' do
    create_rake_test_database
    # using the default character set, the character_set_name should be
    # iso_1 (ISO 8859-1) for the char and varchar data types
    expect_rake_output(/iso_1|UCS/i)
    Rake::Task["db:charset"].invoke
  end

  test 'rake db:collation' do
    create_rake_test_database
    # default (for iso_1) : 'SQL_Latin1_General_CP1_CI_AS'
    expect_rake_output(/SQL_.*/)
    Rake::Task["db:collation"].invoke
  end

  # @override
  def create_rake_test_database(db_name = self.db_name)
    ActiveRecord::Base.establish_connection db_config
    connection = ActiveRecord::Base.connection

    connection.recreate_database(db_name)

    if block_given?
      ActiveRecord::Base.establish_connection db_config.merge :database => db_name
      yield ActiveRecord::Base.connection
    end
    ActiveRecord::Base.connection.disconnect!
  end

  # @override
  def drop_rake_test_database(silence = false)
    ActiveRecord::Base.establish_connection db_config
    connection = ActiveRecord::Base.connection
    begin
      #current_db_name = connection.current_database
      #if current_db_name.upcase == db_name.upcase
        connection.use_database('master')
      #end
      connection.drop_database(db_name)
    rescue => e
      raise e unless silence
    end
    ActiveRecord::Base.connection.disconnect!
  end

  private

  def databases
    select = "SELECT name FROM sys.sysdatabases"

    ActiveRecord::Base.connection.select_rows(select).flatten
  end

end
