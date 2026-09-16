# frozen_string_literal: true

# MSSQL deprecated type definitions
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module Type

        class Text < ActiveRecord::Type::String
          def initialize(**args)
            super
            @limit = 2_147_483_647
          end

          def type
            :text_basic
          end
        end

        class Ntext < ActiveRecord::Type::String
          def initialize(**args)
            super
            @limit = 2_147_483_647
          end

          def type
            :ntext
          end
        end

        class Image < ActiveRecord::Type::Binary
          def initialize(**args)
            super
            @limit = 2_147_483_647
          end

          def type
            :image
          end
        end

      end
    end
  end
end
