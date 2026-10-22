# Portfolio 2: Kaizii MFB Performance Analysis

## Environment and data

The measurements were collected in pgAdmin Query Tool against `Kaizii_MFB` on PostgreSQL 18. The recorded settings were: block size 8,192 bytes, `shared_buffers` 128 MB, `work_mem` 4 MB, `seq_page_cost` 1.0, `random_page_cost` 4.0, and `cpu_tuple_cost` 0.01.

The seeded workload contains 5,000 customers, 5,000 accounts, 202,000 transactions (200,000 transfers and 2,000 reversals), and 404,000 ledger entries. The status check found all 5,000 accounts were `ACTIVE`; therefore this data cannot demonstrate planner behavior for a rare status versus a common status.

The plans in `plans/before.txt` and `plans/after.txt` record the second `EXPLAIN (ANALYZE, BUFFERS)` run for each query. This reduces some cold-cache variation, but the measurements are still from single recorded runs and are sensitive to cache, machine load, and background activity.

## Query plan comparison

| Query | Before (ms) | After (ms) | Observed after-plan behavior |
|---|---:|---:|---|
| Q1 account statement | 126.440 | 0.455 | Uses `idx_ledger_account_statement` for an index-only scan of the requested account's newest ledger entries; 207 shared buffer hits. |
| Q2 daily transfer totals | 670.277 | 58.335 | Uses `idx_transactions_completed_transfer_date` in an index-only scan; 329 shared buffer hits. |
| Q3 customer largest transfers | 473.459 | 31.839 | Uses the customer-account and debit-ledger indexes, then joins transactions and ranks results. |
| Q4 large transfers for review | 845.315 | 1,020.524 | Uses the debit-ledger index, but still scans completed transactions and aggregates many rows. This recorded run was slower. |
| Q5 idempotency lookup | 6.953 | 2.489 | Uses the existing unique index `uq_transactions_idempotency_key`; no new index was needed. |
| Q6 balance reconciliation | 427.498 | 4,690.688 | Still scans and aggregates the ledger to reconcile every account. This recorded run was much slower; the plan still requires broad aggregation. |
| Q7 unbalanced journals audit | 2,338.316 | 3,235.035 | Still scans and groups the transaction and ledger data for the full audit. This recorded run was slower. |
| Q8 net movement including reversals | 758.054 | 700.068 | Still uses a parallel sequential scan and sort; reversal checks use the transaction primary key. The change was modest. |

Q1–Q3 show useful improvements in these runs. Q4, Q6, and Q7 did not improve in the recorded after run, so the indexes should not be described as making every query faster. Q5 is a control lookup that already benefits from its unique constraint. Q6 and Q7 must inspect broad portions of the data to perform their reconciliation and integrity checks. Q8 also processes a broad set of transactions, so its existing primary-key lookups help the reversal checks but do not remove the main scan and sort.

These are observed execution-time differences, not proof that indexes alone caused every change. In particular, Q6's after time is much longer than its before time even though the plan shape remains similar; repeat under controlled conditions before drawing a general conclusion from that result.

## Integrity query outcomes

- Q6 returned 0 discrepancies using the seeded opening balance assumption of NGN 53,000 per account.
- Q7 returned 0 unbalanced journals in the seeded data.
- Q9 reported a 2.0 fan-out ratio for this workload: each completed transfer in the measured sample joined to one debit and one credit ledger entry. The schema does not guarantee exactly two entries for every possible transaction.

## Index storage size

Sizes below were measured with `pg_relation_size` in the Kaizii database.

| Project index | Table | Size | Bytes |
|---|---|---:|---:|
| `idx_accounts_customer_account` | `accounts` | 128 kB | 131,072 |
| `idx_ledger_account_statement` | `ledger_entries` | 23 MB | 23,789,568 |
| `idx_ledger_debit_account_amount` | `ledger_entries` | 9,800 kB | 10,035,200 |
| `idx_ledger_ngn_debit_created` | `ledger_entries` | 9,816 kB | 10,051,584 |
| `idx_transactions_completed_transfer_date` | `transactions` | 7,864 kB | 8,052,736 |

Together, the five project indexes occupy 52,060,160 bytes (about 49.7 MiB). The three ledger indexes are the ones included in the isolated write comparison below. PostgreSQL also has built-in primary-key and unique indexes; they are not counted as project indexes in this table.

## Isolated ledger insert comparison

To avoid changing the live tables, I created two temporary copies of `ledger_entries` in a transaction. One copy had no secondary indexes; the other had temporary versions of all three Kaizii ledger indexes. I inserted the same 404,000 source rows into each with `EXPLAIN (ANALYZE, BUFFERS)`, measured the temporary relations, and rolled the transaction back. The real tables and their indexes were left unchanged.

| Temporary copy | Inserted rows | `EXPLAIN ANALYZE` execution time | Table size | Total size including indexes |
|---|---:|---:|---:|---:|
| No ledger indexes | 404,000 | 10,549.028 ms | 27,582,464 bytes | 27,607,040 bytes |
| Three ledger indexes | 404,000 | 9,312.807 ms | 27,582,464 bytes | 89,866,240 bytes |

The indexed temporary copy used 62,259,200 more total bytes than the unindexed copy (about 59.4 MiB). The indexed insert happened second and was faster in this one observation. The source scan itself also took markedly less time on the second run, which indicates cache effects. Therefore, these single-run times do **not** establish that indexes make inserts faster or quantify a reliable write penalty. Maintaining indexes adds work to inserts and uses additional storage; a repeated, alternating-order benchmark would be needed to estimate its time cost reliably. The extra storage is measured here.

The temporary tables were dropped by rolling back the transaction. No permanent Kaizii table was dropped, truncated, or rewritten.

## Reflection and limitations

This experiment shows the trade-off: selected indexes can make targeted reads much faster, while they consume storage and need maintenance when rows are written. Broad reconciliation and audit queries still need to process much of the data. The test uses one seeded dataset, one run per write scenario, and one PostgreSQL environment; results may differ with more data, different distributions, cache state, or hardware. Account status has no variation in this seed, limiting selectivity demonstrations.

## AI use declaration

AI assistance was used to adapt the study guide to the Kaizii MFB schema, organize the report, and check the interpretation of captured plans and measurements. SQL execution, database outputs, plan timings, and index sizes were taken from the user's Kaizii MFB PostgreSQL database. The student should review and be ready to explain the analysis in their own words.
