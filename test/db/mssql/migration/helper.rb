# helper for smoke migration tests
module MSSQLMigration
  module TestHelper
    attr_reader :connection

    MIGRATION_METHODS = %w[
      change_column_default
      change_column_null
      add_column
      add_timestamps
      remove_column
      rename_column
      add_index
      change_column
      rename_table
      column_exists?
      index_exists?
      add_reference
      add_belongs_to
      remove_reference
      remove_references
      remove_belongs_to
      change_table
    ].freeze

    class CreateColumnModifications < ActiveRecord::Migration[6.0]
      def self.up
        create_table :entries do |t|

          t.timestamps
        end

        create_table :reviews do |t|
          t.references :entry
        end
      end

      def self.down
        drop_table :reviews
        drop_table :entries
      end
    end

    class Entry < ActiveRecord::Base
    end

    class Review < ActiveRecord::Base
    end

    def setup
      @connection = ActiveRecord::Base.connection
      CreateColumnModifications.up
    end

    def teardown
      CreateColumnModifications.down
      ActiveRecord::Base.clear_active_connections!
    end

    private

    delegate(*MIGRATION_METHODS, to: :connection)
  end
end
