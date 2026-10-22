-- Q6: Balance reconciliation.
-- Compares cached account balances with expected balance based on an assumed opening balance
-- of 53,000.00 NGN plus net ledger movements (credits minus debits).
-- The Kaizii schema has no opening_balance column on accounts; an opening balance of 53,000.00 NGN
-- is established during data seeding to prevent intermediate negative balances.
-- Ledger totals are calculated by account and currency to prevent cross-currency summation.
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
