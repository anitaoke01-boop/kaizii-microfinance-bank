-- Portfolio 3 / Kaizii MFB
-- Demonstrates undoing one transfer to a savepoint, then committing the outer transaction.
-- Run connected to Kaizii_MFB. Uses only the P3 demo accounts.

BEGIN;

SAVEPOINT before_p3_transfer;

SELECT public.p3_transfer_funds(
    'P3-DEMO-FROM-0001',
    'P3-DEMO-TO-0001',
    100.00,
    'P3-SAVEPOINT-001'
) AS transaction_id_to_undo;

ROLLBACK TO SAVEPOINT before_p3_transfer;

COMMIT;

-- Read-only verification: balances stay the same and the rolled-back request is absent.
SELECT
    (SELECT balance FROM public.accounts
     WHERE account_number = 'P3-DEMO-FROM-0001') AS sender_balance,
    (SELECT balance FROM public.accounts
     WHERE account_number = 'P3-DEMO-TO-0001') AS receiver_balance,
    (SELECT COUNT(*) FROM public.transactions
     WHERE idempotency_key = 'P3-SAVEPOINT-001') AS saved_transaction_rows;
