# frozen_string_literal: true

module ArJdbc
  module MSSQLConfig
    def build_connection_config(config)
      config = config.deep_dup

      load_jdbc_driver

      config[:driver] ||= database_driver_name

      config[:host] ||= "localhost"
      config[:connection_alive_sql] ||= "SELECT 1"
      config[:lock_timeout] ||= 5000

      config[:url] ||= build_connection_url(config)

      config
    end

    private

    def load_jdbc_driver
      require "jdbc/mssql"

      ::Jdbc::Mssql.load_driver if defined?(::Jdbc::Mssql.load_driver)
    rescue LoadError
      # assuming driver.jar is on the class-path
    end

    def database_driver_name
      "com.microsoft.sqlserver.jdbc.SQLServerDriver"
    end

    def build_connection_url(config)
      url = "".dup
      url << "jdbc:sqlserver://#{config[:host]}"
      url << ( config[:port] ? ":#{config[:port]};" : ';' )
      url << "databaseName=#{config[:database]};" if config[:database]
      url << "instanceName=#{config[:instance]};" if config[:instance]
      url << "sendTimeAsDatetime=#{config[:send_time_as_datetime] || false};"
      url << "loginTimeout=#{config[:login_timeout].to_i};" if config[:login_timeout]
      url << "lockTimeout=#{config[:lock_timeout].to_i};"
      url << "encrypt=#{config[:encrypt]};" if config.key?(:encrypt)
      url << "trustServerCertificate=#{config[:trust_server_certificate]};" if config.key?(:trust_server_certificate)
      app = config[:application_name] || config[:appname] || config[:application]
      url << "applicationName=#{app};" if app
      isc = config[:integrated_security] # Win only - needs sqljdbc_auth.dll
      url << "integratedSecurity=#{isc};" unless isc.nil?
      url
    end
  end
end
