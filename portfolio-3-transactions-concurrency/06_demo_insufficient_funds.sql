-- Portfolio 3 / Kaizii MFB
-- Demonstrates a transfer rejected for insufficient funds, then verifies no changes persisted.
-- Run connected to Kaizii_MFB. Uses only the P3 demo accounts.

DO $test$
BEGIN
    PERFORM public.p3_transfer_funds(
        'P3-DEMO-FROM-0001',
        'P3-DEMO-TO-0001',
        99999.00,
        'P3-INSUFFICIENT-001'
    );

    RAISE EXCEPTION 'P3_TEST_UNEXPECTED_SUCCESS: insufficient-funds transfer was accepted';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM = 'P3_INSUFFICIENT_FUNDS' THEN
            RAISE NOTICE 'PASS: insufficient-funds transfer was rejected';
        ELSE
            RAISE;
        END IF;
END;
$test$;

SELECT
    (SELECT balance FROM public.accounts
     WHERE account_number = 'P3-DEMO-FROM-0001') AS sender_balance,
    (SELECT balance FROM public.accounts
     WHERE account_number = 'P3-DEMO-TO-0001') AS receiver_balance,
    (SELECT COUNT(*) FROM public.transactions
     WHERE idempotency_key = 'P3-INSUFFICIENT-001') AS failed_transaction_rows;
