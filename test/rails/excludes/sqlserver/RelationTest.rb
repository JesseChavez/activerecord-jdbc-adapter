exclude :test_empty_complex_chained_relations, 'column is invalid in the ORDER BY because is not contained in the GROUP BY'
exclude :test_default_scope_order_with_scope_order, 'duplicated column in ORDER'

exclude :test_multiple_where_and_having_clauses, 'users should build their query correctly'
exclude :test_having_with_binds_for_both_where_and_having, 'users should build their query correctly'

exclude :test_using_a_custom_table_affects_the_wheres, 'it need order before take (OFFSET needs ORDER)'
exclude :test_using_a_custom_table_with_joins_affects_the_joins, 'it need order before take (OFFSET needs ORDER)'

exclude :test_reorder_with_first, 'visitor always uses ORDER'
exclude :test_reorder_with_take, 'visitor always uses ORDER'
exclude :"test_find_by_doesn't_have_implicit_ordering", 'visitor always uses ORDER'
exclude :"test_find_by!_doesn't_have_implicit_ordering", 'visitor always uses ORDER'

exclude :test_order_using_scoping, 'duplicated column in ORDER'
