# frozen_string_literal: true

# MSSQL string types definitions
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Type

        class Char < ActiveRecord::Type::String
          def type
            :char
          end
        end

        class Varchar < ActiveRecord::Type::String
          def type
            :varchar
          end
        end

        class VarcharMax < ActiveRecord::Type::String
          def initialize(**args)
            super
            @limit = 2_147_483_647
          end

          def type
            :varchar_max
          end
        end

        class Nchar < ActiveRecord::Type::String
          def type
            :nchar
          end
        end

        # This is  Rails logical string type
        class Nvarchar < ActiveRecord::Type::String
          def type
            :string
          end
        end

        # This is  Rails logical text type
        class NvarcharMax < ActiveRecord::Type::String
          def initialize(**args)
            super
            @limit = 2_147_483_647
          end

          def type
            :text
          end
        end

      end
    end
  end
end
