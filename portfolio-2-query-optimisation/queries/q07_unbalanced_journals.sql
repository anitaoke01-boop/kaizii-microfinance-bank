-- Q7: Unbalanced journals audit.
-- Identifies completed or reversed transactions where ledger debits and credits do not balance.
-- Ensures that debit and credit totals balance within each currency,
-- so equal amounts in different currencies are not treated as balanced.
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
