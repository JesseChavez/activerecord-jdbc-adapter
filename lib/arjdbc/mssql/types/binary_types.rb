# frozen_string_literal: true

# MSSQL binary types definitions
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Type

        class BinaryBasic < ActiveRecord::Type::Binary
          def type
            :binary_basic
          end
        end

        class Varbinary < ActiveRecord::Type::Binary
          def type
            :varbinary
          end
        end

        # This is the Rails binary type
        class VarbinaryMax < ActiveRecord::Type::Binary
          def initialize(**args)
            super
            @limit = 2_147_483_647
          end

          def type
            :binary
          end
        end

      end
    end
  end
end
