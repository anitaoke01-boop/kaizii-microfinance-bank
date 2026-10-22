-- Replace the example with a CUSTOMER email returned by q00.
-- Returns the top 10 completed transfers for the customer separately for each currency_code.
-- Window function partitions by currency_code so amounts in different currencies are not ranked together.
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
