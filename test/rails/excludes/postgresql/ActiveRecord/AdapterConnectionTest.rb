# This is a buggy implementation, not a buggy test.
# Would be fixed by not calling `create_array_of()` in `encode`, which would prevent the transaction becoming materialised
# by accident.
# Related to https://github.com/jruby/activerecord-jdbc-adapter/issues/830
exclude :test_unmaterialized_transaction_state_can_be_restored_after_a_reconnect,
        'PG::TextEncoder::Array shim currently breaks lazy transactions'
