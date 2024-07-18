# frozen_string_literal: true

ArJdbc::ConnectionMethods.module_eval do
  def mssql_adapter_class
    ConnectionAdapters::MSSQLAdapter
  end

  # NOTE: Assumes SQLServer SQL-JDBC driver on the class-path.
  def mssql_connection(config)
    config = config.deep_dup

    config[:adapter_spec] ||= ::ArJdbc::MSSQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::MSSQLAdapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    config[:host] ||= 'localhost'
    config[:driver] ||= 'com.microsoft.sqlserver.jdbc.SQLServerDriver'
    config[:connection_alive_sql] ||= 'SELECT 1'
    config[:lock_timeout] ||= 5000

    config[:url] ||= begin
      url = ''.dup
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

    jdbc_connection(config)
  end

  alias_method :jdbcmssql_connection, :mssql_connection
  alias_method :sqlserver_connection, :mssql_connection
  alias_method :jdbcsqlserver_connection, :mssql_connection
end
