-- Q4: Large transfers for review (customers with outgoing NGN transfers of at least 4,000 NGN in the last 90 days).
-- Note: This query identifies high-value transfer activity for compliance review; it does not confirm fraud.
-- The 4,000 threshold is in NGN, and calculations are kept specific to NGN.
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
