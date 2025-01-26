require 'arjdbc'
require 'arjdbc/mssql/adapter'
require 'arjdbc/mssql/connection_methods'

module ArJdbc
  MsSQL = MSSQL # compatibility with 1.2
end

ArJdbc.warn_unsupported_adapter 'mssql', [7, 1] # warns on AR >= 4.2
