-- Read-only: find suitable existing test values for Q01, Q03, and Q05.
-- Returns one row with three columns containing existing, suitable data.
SELECT
    (
        SELECT a.account_number
        FROM accounts AS a
        WHERE EXISTS (
            SELECT 1 FROM ledger_entries AS l
            WHERE l.account_id = a.account_id
        )
        ORDER BY a.account_id
        LIMIT 1
    ) AS account_number,
    (
        SELECT c.email
        FROM customers AS c
        WHERE EXISTS (
            SELECT 1
            FROM accounts AS a
            JOIN ledger_entries AS l ON l.account_id = a.account_id AND l.direction = 'DEBIT'
            JOIN transactions AS t ON t.transaction_id = l.transaction_id
            WHERE a.customer_id = c.customer_id
              AND t.transaction_type = 'TRANSFER'
              AND t.status = 'COMPLETED'
        )
        ORDER BY c.customer_id
        LIMIT 1
    ) AS customer_email,
    (
        SELECT t.idempotency_key
        FROM transactions AS t
        WHERE t.idempotency_key IS NOT NULL
        ORDER BY t.transaction_id
        LIMIT 1
    ) AS idempotency_key;
