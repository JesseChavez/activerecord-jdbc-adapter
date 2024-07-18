# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      class Version
        attr_reader :major
        attr_reader :complete
        attr_reader :level
        attr_reader :edition

        VERSION_YEAR = {
          '8'  => '2000',
          '9'  => '2005',
          '10' => '2008',
          '11' => '2012',
          '12' => '2014',
          '13' => '2016',
          '14' => '2017',
          '15' => '2019',
          '16' => '2022'
        }.freeze

        def initialize(version_array = [])
          @complete, @major, @level, @edition = version_array
        end

        def product_name
          return system_name unless year

          "#{system_name} #{year}"
        end

        def system_name
          'Microsoft SQL Server'
        end

        def year
          VERSION_YEAR[major]
        end

        def min_year
          VERSION_YEAR[min_major]
        end

        def min_major
          '13'
        end

        def support_message
          "This adapter supports #{system_name} >= #{min_year}."
        end
      end
    end
  end
end
