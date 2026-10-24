-- Portfolio 3 / Kaizii MFB
-- Calls the same 250 NGN transfer twice with the same idempotency key.
-- The second call should return the first transaction ID without moving money again.
-- Run connected to Kaizii_MFB. Uses only the P3 demo accounts.

DO $test$
DECLARE
    v_first_transaction_id  INTEGER;
    v_second_transaction_id INTEGER;
BEGIN
    v_first_transaction_id := public.p3_transfer_funds(
        'P3-DEMO-FROM-0001',
        'P3-DEMO-TO-0001',
        250.00,
        'P3-IDEMPOTENCY-001'
    );

    v_second_transaction_id := public.p3_transfer_funds(
        'P3-DEMO-FROM-0001',
        'P3-DEMO-TO-0001',
        250.00,
        'P3-IDEMPOTENCY-001'
    );

    IF v_first_transaction_id IS DISTINCT FROM v_second_transaction_id THEN
        RAISE EXCEPTION 'P3_IDEMPOTENCY_TEST_FAILED: repeated request returned a different transaction ID';
    END IF;

    RAISE NOTICE 'PASS: repeated request returned transaction ID %', v_first_transaction_id;
END;
$test$;

SELECT
    (SELECT balance FROM public.accounts
     WHERE account_number = 'P3-DEMO-FROM-0001') AS sender_balance,
    (SELECT balance FROM public.accounts
     WHERE account_number = 'P3-DEMO-TO-0001') AS receiver_balance,
    (SELECT COUNT(*) FROM public.transactions
     WHERE idempotency_key = 'P3-IDEMPOTENCY-001') AS transaction_rows,
    (SELECT COUNT(*)
       FROM public.ledger_entries AS l
       JOIN public.transactions AS t USING (transaction_id)
      WHERE t.idempotency_key = 'P3-IDEMPOTENCY-001') AS ledger_rows;
