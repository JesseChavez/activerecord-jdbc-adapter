require 'test_helper'
require 'db/mssql'

class MSSQLValidationTest < Test::Unit::TestCase
  class CreateValidationTests < ActiveRecord::Migration[6.0]
    def self.up
      create_table :validation_default_tests do |t|
        t.string :name
        t.string :email

        t.timestamps
      end

      create_table :validation_tests do |t|
        t.string :name
        t.string :email

        t.timestamps
      end
    end

    def self.down
      drop_table :validation_default_tests
      drop_table :validation_tests
    end
  end

  class ValidationDefaultTest < ActiveRecord::Base
    # The default behavior 'case_sensitive' respects the default database collation.
    validates :name, uniqueness: true

    # NULL should not affect validations since null is allowed
    validates :email, uniqueness: { case_sensitive: true, allow_nil: true }
  end

  class ValidationTest < ActiveRecord::Base
    # The default behavior 'case_sensitive' respects the default database collation.
    validates :name, uniqueness: { case_sensitive: true }

    # NULL should not affect validations since null is allowed
    validates :email, uniqueness: { case_sensitive: false, allow_nil: true }
  end

  def setup
    CreateValidationTests.up
  end

  def teardown
    CreateValidationTests.down
    ActiveRecord::Base.connection_handler.clear_active_connections!(:all)
  end

  def test_validate_uniqueness_by_default_database_collation
    # Case insensitive, accent sensitive collation SQL_Latin1_General_CP1_CI_AS
    # by default in not changed in the mssql server
    topic1 = ValidationDefaultTest.new(name: "Hello world!")
    topic2 = ValidationDefaultTest.new(name: "Hello world!")
    topic3 = ValidationDefaultTest.new(name: "hello world!")

    # save initial record
    assert topic1.valid?
    assert topic1.save

    # invalid record
    assert_false topic2.valid?
    assert_false topic2.save

    # invalid record
    assert_false topic3.valid?
    assert_false topic3.save

    # these select queries are done in default database collation
    assert_equal 1, ValidationDefaultTest.where(name: "Hello world!").count
    assert_equal 1, ValidationDefaultTest.where(name: "hello world!").count
  end

  def test_validate_case_sensitive_uniqueness
    poet1 = ValidationTest.new(name: 'César Vallejo')

    assert poet1.valid?
    assert poet1.save

    poet2 = ValidationTest.new(name: 'césar vallejo')

    assert poet2.valid?
    assert poet2.save

    poet3 = ValidationTest.new(name: 'cesar vallejo')

    assert poet3.valid?
    assert poet3.save

    # these select queries are done in default database collation
    assert_equal 2, ValidationTest.where(name: "César Vallejo").count
    assert_equal 2, ValidationTest.where(name: "césar Vallejo").count
    assert_equal 1, ValidationTest.where(name: "cesar Vallejo").count
  end

  def test_validate_case_sensitive_uniqueness_accent_insensitive
    adapter = ActiveRecord::ConnectionAdapters::MSSQLAdapter
    adapter.cs_equality_operator = 'COLLATE Latin1_General_CS_AI_WS'

    poet1 = ValidationTest.new(name: 'César Vallejo')

    assert poet1.valid?
    assert poet1.save

    poet2 = ValidationTest.new(name: 'césar vallejo')

    assert poet2.valid?
    assert poet2.save

    poet3 = ValidationTest.new(name: 'cesar vallejo')

    assert_false poet3.valid?
    assert_false poet3.save

    # these select queries are done in default database collation
    assert_equal 0, ValidationTest.where(name: "cesar vallejo").count
    assert_equal 2, ValidationTest.where(name: "césar vallejo").count
    assert_equal 2, ValidationTest.where(name: "César Vallejo").count
  end
end
