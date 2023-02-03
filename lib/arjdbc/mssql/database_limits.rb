# frozen_string_literal: true

module ActiveRecord
 module ConnectionAdapters
   module MSSQL
     module DatabaseLimits

       # Returns the maximum number of elements in an IN (x,y,z) clause.
       # NOTE: Could not find a limit for IN in mssql but 10000 seems to work
       # with the active record tests
       # FIXME: this method was deprecated in rails 6.1, and it seems the only
       # code that used this method was the oracle visitor, the code was moved
       # from rails to the adapter itself.
       #   https://github.com/rsim/oracle-enhanced/pull/2008/files
       # related:
       #   https://github.com/rails/rails/pull/38946
       #   https://github.com/rails/rails/pull/39057
       def in_clause_length
         10_000
       end

       private

       # the max bind params is 2100 but it seems
       # the jdbc uses 2 for something
       def bind_params_length
         2_098
       end

       # max number of insert rows in mssql
       def insert_rows_length
         1_000
       end

     end
   end
 end
end
