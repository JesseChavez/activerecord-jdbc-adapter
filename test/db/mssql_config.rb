# currently sqlserver is the default driver
# NOTE: to change you sqlserver password you can use
#
#   ALTER LOGIN [arjdbc] with PASSWORD = N'password'
#
MSSQL_CONFIG = {
  adapter:  'sqlserver',
  database: ENV['SQLDATABASE'] || 'arjdbc_61_test',
  username: ENV['SQLUSER'] || 'arjdbc',
  password: ENV['SQLPASS'] || 'password',
  host:     ENV['SQLHOST'] || 'localhost'
}

MSSQL_CONFIG[:trust_server_certificate] = true

MSSQL_CONFIG[:port] = ENV['SQLPORT'] if ENV['SQLPORT']

unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  MSSQL_CONFIG[:prepared_statements] = ps
end


if ENV['DRIVER'] =~ /jTDS/i
  # change adapter for jTDS
  MSSQL_CONFIG[:adapter] = 'mssql'
  return
end

# Using MS official  SQL JDBC driver
require 'jdbc/sqlserver'

# NOTE: the below rescue does not work anymore.
# begin
#   silence_warnings { Java::JavaClass.for_name(Jdbc::SQLServer.driver_name) }
#   return
# rescue NameError => e
#   warn "unable to load java class with name: #{e}"
# end

begin
  Jdbc::SQLServer.load_driver
rescue LoadError => e
  warn "If you want to use a specific version please setup the mssql driver to run the MS-SQL tests!\n#{e}"
  warn "Place the jar in the folder 'test/jars/' and update the jar name in test/jdbc/sqlserver.rb file"
  require 'jdbc/mssql'
  warn 'using the jdbc-mssql gem to run test.'
end
