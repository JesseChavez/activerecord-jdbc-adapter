# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      class TypeMetadata < DelegateClass(SqlTypeMetadata)
        undef to_yaml if method_defined?(:to_yaml)

        include Deduplicable

        def initialize(type_metadata)
          super(type_metadata)
        end

        def ==(other)
          other.is_a?(TypeMetadata) &&
            __getobj__ == other.__getobj__
        end

        alias eql? ==

        def hash
          TypeMetadata.hash ^
            __getobj__.hash
        end

        private

        def deduplicated
          __setobj__(__getobj__.deduplicate)
          super
        end
      end
    end
  end
end
