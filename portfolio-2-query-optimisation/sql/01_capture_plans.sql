-- Portfolio 2: Capture baseline execution plans for Q1 to Q8 (before indexing)
-- File: portfolio-2-query-optimisation/sql/01_capture_plans.sql
--
-- In pgAdmin Query Tool, run each query individually.
-- Run each query TWICE to warm the cache, and record the second plan output into plans/before.txt.

-- =====================================================================
-- Q1: Account Statement (50 most recent ledger entries for one account)
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT l.entry_id, l.created_at, l.direction, l.amount, l.currency_code,
       t.transaction_id, t.transaction_type, t.status
FROM ledger_entries l JOIN transactions t ON t.transaction_id=l.transaction_id
WHERE l.account_id=(SELECT account_id FROM accounts
                    WHERE account_number='P2-ACC-0000000001')
ORDER BY l.created_at DESC, l.entry_id DESC
LIMIT 50;

-- =====================================================================
-- Q2: Daily Transfer Totals (last 30 days)
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('day', created_at) AS day,
       currency_code,
       count(*) AS transfers,
       sum(amount) AS total_amount
FROM transactions
WHERE transaction_type = 'TRANSFER' AND status = 'COMPLETED'
  AND created_at >= now() - interval '30 days'
GROUP BY date_trunc('day', created_at), currency_code
ORDER BY day, currency_code;

-- =====================================================================
-- Q3: Customer Largest Transfers (top 10 per currency)
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS)
WITH customer_transfers AS (
    SELECT t.transaction_id,
           l.amount AS amount_debited,
           t.currency_code,
           t.created_at,
           row_number() OVER (
               PARTITION BY t.currency_code
               ORDER BY l.amount DESC, t.created_at DESC
           ) AS rank_in_currency
    FROM accounts a
    JOIN ledger_entries l ON l.account_id = a.account_id AND l.direction = 'DEBIT'
    JOIN transactions t ON t.transaction_id = l.transaction_id
    WHERE a.customer_id = (SELECT customer_id FROM customers
                           WHERE email = 'p2seed-customer-00001@example.invalid')
      AND t.transaction_type = 'TRANSFER'
      AND t.status = 'COMPLETED'
)
SELECT transaction_id,
       amount_debited,
       currency_code,
       created_at,
       rank_in_currency
FROM customer_transfers
WHERE rank_in_currency <= 10
ORDER BY currency_code, rank_in_currency;

-- =====================================================================
-- Q4: Large Transfers for Review (>= 4,000 NGN in last 90 days)
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.customer_id,
       l.currency_code,
       count(*) AS large_transfers,
       sum(l.amount) AS total_sent
FROM ledger_entries l
JOIN accounts a ON a.account_id = l.account_id
JOIN transactions t ON t.transaction_id = l.transaction_id
WHERE l.direction = 'DEBIT'
  AND l.currency_code = 'NGN'
  AND l.amount >= 4000
  AND l.created_at >= now() - interval '90 days'
  AND t.transaction_type = 'TRANSFER'
  AND t.status = 'COMPLETED'
GROUP BY a.customer_id, l.currency_code
ORDER BY large_transfers DESC, total_sent DESC
LIMIT 10;

-- =====================================================================
-- Q5: Idempotency Key Lookup
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM transactions
WHERE idempotency_key='P2SEED-XFER-00025000';

-- =====================================================================
-- Q6: Balance Reconciliation (reconciles against 53,000 NGN opening balance)
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS)
WITH ledger_totals AS (
  SELECT account_id,
         currency_code,
         sum(CASE WHEN direction = 'CREDIT' THEN amount
                  WHEN direction = 'DEBIT' THEN -amount ELSE 0 END) AS ledger_balance
  FROM ledger_entries
  GROUP BY account_id, currency_code
)
SELECT a.account_id,
       a.account_number,
       a.currency_code,
       a.balance AS cached_balance,
       coalesce(l.ledger_balance, 0) AS net_ledger_movement,
       (53000.00 + coalesce(l.ledger_balance, 0)) AS expected_balance,
       a.balance - (53000.00 + coalesce(l.ledger_balance, 0)) AS difference
FROM accounts a
LEFT JOIN ledger_totals l
  ON l.account_id = a.account_id AND l.currency_code = a.currency_code
WHERE a.balance <> (53000.00 + coalesce(l.ledger_balance, 0))
ORDER BY a.account_id;

-- =====================================================================
-- Q7: Unbalanced Journals Audit
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.transaction_id,
       t.transaction_type,
       t.amount,
       t.currency_code AS transaction_currency,
       l.currency_code AS ledger_currency,
       count(l.entry_id) AS entry_count,
       coalesce(sum(l.amount) FILTER (WHERE l.direction = 'DEBIT'), 0) AS total_debits,
       coalesce(sum(l.amount) FILTER (WHERE l.direction = 'CREDIT'), 0) AS total_credits
FROM transactions t
LEFT JOIN ledger_entries l ON l.transaction_id = t.transaction_id
WHERE t.status IN ('COMPLETED', 'REVERSED')
GROUP BY t.transaction_id, t.transaction_type, t.amount, t.currency_code, l.currency_code
HAVING count(l.entry_id) = 0
    OR l.currency_code IS NULL
    OR coalesce(sum(l.amount) FILTER (WHERE l.direction = 'DEBIT'), 0)
       <> coalesce(sum(l.amount) FILTER (WHERE l.direction = 'CREDIT'), 0)
    OR l.currency_code <> t.currency_code;

-- =====================================================================
-- Q8: Net Movement Including Reversals
-- =====================================================================
EXPLAIN (ANALYZE, BUFFERS)
WITH eligible_transactions AS (
    SELECT t.transaction_id,
           t.transaction_type,
           t.status,
           t.amount,
           t.currency_code,
           t.created_at,
           t.reversal_of_transaction_id,
           CASE
               WHEN t.transaction_type = 'REVERSAL'
                AND t.status = 'COMPLETED'
                AND t.reversal_of_transaction_id IS NOT NULL
                AND EXISTS (
                    SELECT 1
                    FROM transactions orig
                    WHERE orig.transaction_id = t.reversal_of_transaction_id
                      AND orig.transaction_type = 'TRANSFER'
                      AND orig.status = 'REVERSED'
                      AND orig.currency_code = t.currency_code
                ) THEN true
               ELSE false
           END AS is_valid_linked_reversal
    FROM transactions t
    WHERE t.created_at >= now() - interval '90 days'
      AND t.transaction_type IN ('TRANSFER', 'REVERSAL')
)
SELECT currency_code,
       count(*) FILTER (WHERE transaction_type = 'TRANSFER' AND status = 'COMPLETED')
         AS transfers_still_completed,
       count(*) FILTER (WHERE transaction_type = 'TRANSFER' AND status = 'REVERSED')
         AS transfers_later_reversed,
       coalesce(sum(amount) FILTER
         (WHERE transaction_type = 'TRANSFER' AND status IN ('COMPLETED', 'REVERSED')), 0)
         AS original_transfer_amount,
       count(*) FILTER (WHERE is_valid_linked_reversal)
         AS completed_reversals,
       coalesce(sum(amount) FILTER (WHERE is_valid_linked_reversal), 0)
         AS completed_reversal_amount,
       coalesce(sum(CASE
         WHEN transaction_type = 'TRANSFER' AND status IN ('COMPLETED', 'REVERSED') THEN amount
         WHEN is_valid_linked_reversal THEN -amount
         ELSE 0 END), 0) AS net_amount_after_reversals
FROM eligible_transactions
GROUP BY currency_code
ORDER BY currency_code;
