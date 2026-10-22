-- Replace the example with an ACCOUNT_NUMBER returned by q00.
SELECT l.entry_id, l.created_at, l.direction, l.amount, l.currency_code,
       t.transaction_id, t.transaction_type, t.status
FROM ledger_entries l JOIN transactions t ON t.transaction_id=l.transaction_id
WHERE l.account_id=(SELECT account_id FROM accounts
                    WHERE account_number='P2-ACC-0000000001')
ORDER BY l.created_at DESC, l.entry_id DESC
LIMIT 50;
