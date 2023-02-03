# I tried 1000 and still SQL Server fails to process the query
exclude :test_preloading_too_many_ids, 'does not have a limit, mssql fails to load many record created by the fixture'
exclude :test_eager_loading_too_many_ids, 'eager_load does not have a limit, mssql fails to load 65535 record created by the fixture'
