# Portfolio 2 Task 6: Index write and storage measurements

## Safe method

The comparison used two temporary copies of `public.ledger_entries` in one transaction. The unindexed copy had no secondary indexes. The indexed copy had temporary versions of all three ledger indexes from the Kaizii project. The same 404,000 ledger rows were inserted into each with `EXPLAIN (ANALYZE, BUFFERS)`. Temporary table sizes were measured, then the transaction was rolled back. No permanent Kaizii table was changed.

## Results from this run

| Scenario | Rows inserted | Execution time | Table size | Total size |
|---|---:|---:|---:|---:|
| No ledger indexes | 404,000 | 10,549.028 ms | 27,582,464 bytes | 27,607,040 bytes |
| Three ledger indexes | 404,000 | 9,312.807 ms | 27,582,464 bytes | 89,866,240 bytes |

The three-index copy used 62,259,200 more bytes in total (about 59.4 MiB). Although the indexed insert was faster in this single run, it ran second; its source scan was also much faster, indicating cache effects. Do not claim this proves that indexes accelerate inserts. Repeated alternating-order runs would be needed for a reliable time comparison. Maintaining indexes adds work to writes and uses storage; the additional storage is directly measured here.

## Sizes of permanent project indexes

| Index | Table | Size | Bytes |
|---|---|---:|---:|
| `idx_accounts_customer_account` | `accounts` | 128 kB | 131,072 |
| `idx_ledger_account_statement` | `ledger_entries` | 23 MB | 23,789,568 |
| `idx_ledger_debit_account_amount` | `ledger_entries` | 9,800 kB | 10,035,200 |
| `idx_ledger_ngn_debit_created` | `ledger_entries` | 9,816 kB | 10,051,584 |
| `idx_transactions_completed_transfer_date` | `transactions` | 7,864 kB | 8,052,736 |

The write experiment rolled back successfully, which dropped its temporary tables. The permanent indexes above remain in the Kaizii database.
