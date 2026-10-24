-- Portfolio 3 / Kaizii MFB
-- Read-only check that the rollback left balances unchanged and saved no transaction.
-- Run connected to Kaizii_MFB after 04_demo_rollback.sql.

SELECT
    (SELECT balance FROM public.accounts
     WHERE account_number = 'P3-DEMO-FROM-0001') AS sender_balance,
    (SELECT balance FROM public.accounts
     WHERE account_number = 'P3-DEMO-TO-0001') AS receiver_balance,
    EXISTS (
        SELECT 1 FROM public.transactions
         WHERE idempotency_key = 'P3-ROLLBACK-001'
    ) AS rollback_transaction_saved;
