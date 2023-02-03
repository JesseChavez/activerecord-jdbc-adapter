exclude :test_read_committed, 'to pass this we can enable SNAPSHOT ON'
exclude :test_repeatable_read, 'this is very strict and  will get a lock for anything (it is better o set an LockTimeout)'
