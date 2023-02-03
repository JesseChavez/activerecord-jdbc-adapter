# we SQL Server is strict about what goes in in ORDER BY, SELECT, GROUP BY, etc.
exclude :test_group_by_with_limit_and_offset, 'column is invalid in the ORDER BY because is not contained in the GROUP BY'
exclude :test_group_by_with_offset, 'column is invalid in the ORDER BY because is not contained in the GROUP BY'
exclude :test_limit_with_offset_is_kept, 'sqlserver does not have LIMIT'
exclude :test_having_with_strong_parameters, 'column is invalid in the HAVING because is not contained in the GROUP BY'
#exclude :test_distinct_count_all_with_custom_select_and_order, 'need and name'
exclude :test_limit_is_kept, 'sqlserver does not have LIMIT'
exclude :test_should_return_decimal_average_of_integer_field, 'in sqlserver result inherit the type of column'
exclude :test_group_by_with_limit, 'column is invalid in the ORDER BY because is not contained in the GROUP BY'
