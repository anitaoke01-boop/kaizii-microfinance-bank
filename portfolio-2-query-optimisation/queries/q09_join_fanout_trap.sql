-- Q9: Join fan-out trap demonstration.
-- Demonstrates how joining transactions to ledger entries inflates aggregated amounts
-- because each transfer joins to multiple ledger lines.
-- Aggregations are calculated by currency_code to prevent cross-currency summation.
WITH eligible AS (
  SELECT transaction_id, amount, currency_code
  FROM transactions
  WHERE transaction_type = 'TRANSFER' AND status = 'COMPLETED'
    AND created_at >= now() - interval '30 days'
),
correct AS (
  SELECT currency_code,
         sum(amount) AS correct_total,
         count(*) AS transfer_count
  FROM eligible
  GROUP BY currency_code
),
joined AS (
  SELECT e.currency_code,
         sum(e.amount) AS fan_out_total,
         count(l.entry_id) AS joined_ledger_rows
  FROM eligible e
  JOIN ledger_entries l ON l.transaction_id = e.transaction_id
  GROUP BY e.currency_code
)
SELECT c.currency_code,
       j.fan_out_total,
       c.correct_total,
       CASE WHEN c.correct_total IS NULL OR c.correct_total = 0 THEN NULL
            ELSE j.fan_out_total / c.correct_total END AS fan_out_ratio,
       c.transfer_count,
       j.joined_ledger_rows
FROM correct c
JOIN joined j ON j.currency_code = c.currency_code
ORDER BY c.currency_code;
