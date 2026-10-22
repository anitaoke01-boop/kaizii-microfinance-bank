-- Q2: Daily transfer totals for completed transfers in the last 30 days.
-- Totals are grouped by day and currency_code to avoid adding amounts across different currencies.
SELECT date_trunc('day', created_at) AS day,
       currency_code,
       count(*) AS transfers,
       sum(amount) AS total_amount
FROM transactions
WHERE transaction_type = 'TRANSFER' AND status = 'COMPLETED'
  AND created_at >= now() - interval '30 days'
GROUP BY date_trunc('day', created_at), currency_code
ORDER BY day, currency_code;
