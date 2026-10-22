# Portfolio 2 performance comparison (Q1–Q3)

Measurements use the second `EXPLAIN (ANALYZE, BUFFERS)` run for each query in pgAdmin. The query text, filters, database (`Kaizii_MFB`) and data were kept the same before and after adding indexes.

| Query | Before | After | Change | Main plan change |
|---|---:|---:|---:|---|
| Q1: account statement | 126.440 ms | 0.455 ms | 99.64% faster (about 278×) | The parallel sequential scan of `ledger_entries` was replaced by an index-only scan using `idx_ledger_account_statement`; shared buffer hits fell from 3,879 to 207. |
| Q2: daily transfer totals | 670.277 ms | 58.335 ms | 91.30% faster (about 11.5×) | The parallel sequential scan of `transactions` was replaced by an index-only scan using `idx_transactions_completed_transfer_date`; shared buffer hits fell from 5,800 to 329. |
| Q3: customer largest transfers | 473.459 ms | 31.839 ms | 93.28% faster (about 14.9×) | The after plan uses the targeted account and ledger indexes and reduces the work needed before ranking the customer’s transfers. |

## Interpretation and limitations

The indexes improved these measured runs substantially. Q1 benefits from finding the selected account's ledger rows in statement order. Q2 benefits from reading completed-transfer rows in the requested date range from the partial index. Q3 benefits from the customer-account and debit-ledger indexes before ranking. Sorting and aggregation remain where the queries need them.

Execution times can vary with cache state and machine load. Treat these values as evidence from this run, not a universal guarantee. Q4–Q8 after-index plans have not yet been captured and compared; do not present this as the complete Portfolio 2 comparison.

## Evidence files

- `plans/before.txt` — baseline plans for Q1–Q8.
- `plans/after.txt` — after-index plans captured so far (Q1, Q2 and Q3).
- `sql/03_create_indexes.sql` — additive index definitions used for the tuning run.
