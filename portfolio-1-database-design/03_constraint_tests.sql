-- Portfolio 1: Kaizii Microfinance Bank
-- Row-level constraint tests. All synthetic test rows are rolled back.
-- Run after 02_create_tables.sql in a test database.

BEGIN;

DO $$
DECLARE
    test_customer_id INTEGER;
    test_transaction_id INTEGER;
    test_token TEXT := substr(md5(clock_timestamp()::text || random()::text), 1, 12);
BEGIN
    INSERT INTO customers (
        first_name, last_name, email, phone_number, customer_type, country_code
    )
    VALUES (
        'Constraint', 'Test', 'constraint-' || test_token || '@example.invalid',
        'T' || test_token, 'INDIVIDUAL', 'NG'
    )
    RETURNING customer_id INTO test_customer_id;

    INSERT INTO transactions (transaction_type, amount, currency_code)
    VALUES ('DEPOSIT', 1.00, 'NGN')
    RETURNING transaction_id INTO test_transaction_id;

    -- Negative account balances must be rejected.
    BEGIN
        INSERT INTO accounts (
            customer_id, account_number, account_type, currency_code, balance
        ) VALUES (
            NULL, 'TST-' || test_token, 'CLEARING', 'NGN', -100.00
        );
        RAISE EXCEPTION 'FAIL: negative account balance was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: negative account balance rejected';
    END;

    -- Transaction amounts must be greater than zero.
    BEGIN
        INSERT INTO transactions (transaction_type, amount, currency_code)
        VALUES ('DEPOSIT', 0, 'NGN');
        RAISE EXCEPTION 'FAIL: zero transaction amount was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: zero transaction amount rejected';
    END;

    -- Use a real customer so this test reaches the KYC status check.
    BEGIN
        INSERT INTO kyc_records (customer_id, id_type, verification_status)
        VALUES (test_customer_id, 'TEST_ID', 'INVALID');
        RAISE EXCEPTION 'FAIL: invalid KYC status was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: invalid KYC status rejected';
    END;

    BEGIN
        INSERT INTO beneficiaries (
            customer_id, beneficiary_name, bank_name,
            country_code, account_number, currency_code
        ) VALUES (
            -999999, 'Test Beneficiary', 'Test Bank',
            'NG', 'TEST-' || test_token, 'NGN'
        );
        RAISE EXCEPTION 'FAIL: nonexistent beneficiary customer was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS: nonexistent beneficiary customer rejected';
    END;

    -- A real customer ensures this test reaches the linked-account status check.
    BEGIN
        INSERT INTO linked_accounts (
            customer_id, bank_name, country_code, account_number,
            currency_code, verification_status
        ) VALUES (
            test_customer_id, 'Test Bank', 'NG', 'LINK-' || test_token,
            'NGN', 'INVALID'
        );
        RAISE EXCEPTION 'FAIL: invalid linked-account status was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: invalid linked-account status rejected';
    END;

    -- The nested block rolls back the first insert when the duplicate is rejected.
    BEGIN
        INSERT INTO transactions (
            idempotency_key, transaction_type, amount, currency_code
        ) VALUES ('IDEMP-' || test_token, 'DEPOSIT', 100.00, 'NGN');
        INSERT INTO transactions (
            idempotency_key, transaction_type, amount, currency_code
        ) VALUES ('IDEMP-' || test_token, 'DEPOSIT', 100.00, 'NGN');
        RAISE EXCEPTION 'FAIL: duplicate idempotency key was accepted';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PASS: duplicate idempotency key rejected';
    END;

    BEGIN
        INSERT INTO fraud_flags (transaction_id, reason, review_status)
        VALUES (test_transaction_id, 'Test flag', 'INVALID');
        RAISE EXCEPTION 'FAIL: invalid fraud review status was accepted';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: invalid fraud review status rejected';
    END;
END $$;

ROLLBACK;
