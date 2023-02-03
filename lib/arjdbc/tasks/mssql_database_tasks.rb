# frozen_string_literal: true

require 'active_record/tasks/database_tasks'

module ArJdbc
  module Tasks # :nodoc:
    class MSSQLDatabaseTasks # :nodoc:
      delegate :connection, to: ActiveRecord::Base
      delegate :establish_connection, to: ActiveRecord::Base
      delegate :clear_active_connections!, to: ActiveRecord::Base

      def self.using_database_configurations?
        true
      end

      def initialize(db_config)
        @db_config = db_config
        @configuration_hash = db_config.configuration_hash
      end

      def create
        establish_master_connection
        connection.create_database(db_config.database, creation_options)
        establish_connection(db_config)
      rescue ActiveRecord::StatementInvalid => e
        case e.message
        when /database .* already exists/i
          raise ActiveRecord::Tasks::DatabaseAlreadyExists
        else
          raise
        end
      end

      def drop
        establish_master_connection
        connection.drop_database(db_config.database)
      end

      def charset
        connection.charset
      end

      def collation
        connection.collation
      end

      def purge
        clear_active_connections!
        drop
        create
      end

      def structure_dump(filename, _extra_flags)
        args = prepare_command_options

        args.concat(["-f #{filename}"])

        run_cmd('mssql-scripter', args, 'dumping')
      end

      def structure_load(filename, _extra_flags)
        args = prepare_command_options

        args.concat(["-i #{filename}"])

        run_cmd('mssql-cli', args, 'loading')
      end

      private

      attr_reader :db_config, :configuration_hash

      def creation_options
        {}.tap do |options|
          options[:collation] = configuration_hash[:collation] if configuration_hash.include?(:collation)

          # azure creation options
          options[:azure_maxsize] = configuration_hash[:azure_maxsize] if configuration_hash.include?(:azure_maxsize)
          options[:azure_edition] = configuration_hash[:azure_edition] if configuration_hash.include?(:azure_edition)

          if configuration_hash.include?(:azure_service_objective)
            options[:azure_service_objective] = configuration_hash[:azure_service_objective]
          end
        end
      end

      def establish_master_connection
        establish_connection(configuration_hash.merge(database: 'master'))
      end

      def prepare_command_options
        {
          server: '-S',
          database: '-d',
          username: '-U',
          password: '-P'
        }.map { |option, arg| "#{arg} #{config_for_cli[option]}" }
      end

      def config_for_cli
        {}.tap do |options|
          if configuration_hash[:host].present? && configuration_hash[:port].present?
            options[:server] = "#{configuration_hash[:host]},#{configuration_hash[:port]}"
          elsif configuration_hash[:host].present?
            options[:server] = configuration_hash[:host]
          end

          options[:database] = configuration_hash[:database] if configuration_hash[:database].present?
          options[:username] = configuration_hash[:username] if configuration_hash[:username].present?
          options[:password] = configuration_hash[:password] if configuration_hash[:password].present?
        end
      end

      def run_cmd(cmd, args, action)
        fail run_cmd_error(cmd, args, action) unless Kernel.system(cmd, *args)
      end

      def run_cmd_error(cmd, args, action)
        msg = +"failed to execute:\n"
        msg << "#{cmd} #{args.join(' ')}\n\n"
        msg << "Failed #{action} structure, please check the output above for any errors"
        msg << " and make sure that `#{cmd}` is installed in your PATH and has proper permissions.\n\n"
        msg
      end
    end

    module DatabaseTasksMSSQL
      extend ActiveSupport::Concern

      module ClassMethods

      def check_protected_environments!
        super
      rescue ActiveRecord::JDBCError => e
        case e.message
        when /cannot open database .* requested by the login/i
        else
          raise
        end
      end

      end
    end

    ActiveRecord::Tasks::DatabaseTasks.send(:include, DatabaseTasksMSSQL)
  end
end
