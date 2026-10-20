-- Portfolio 1: Kaizii Microfinance Bank
-- Trigger tests for transfer-currency and completed-ledger rules.
-- Requires the trigger migration used by the project to be installed first.
-- All test rows are synthetic and rolled back at the end.

BEGIN;

DO $$
DECLARE
    test_customer_id INTEGER;
    source_account_id INTEGER;
    destination_account_id INTEGER;
    foreign_currency_account_id INTEGER;
    test_transaction_id INTEGER;
    test_token TEXT := substr(md5(clock_timestamp()::text || random()::text), 1, 12);
BEGIN
    INSERT INTO customers (
        first_name, last_name, email, phone_number, customer_type, country_code
    ) VALUES (
        'Trigger', 'Test', 'trigger-' || test_token || '@example.invalid',
        'T' || test_token, 'INDIVIDUAL', 'NG'
    ) RETURNING customer_id INTO test_customer_id;

    INSERT INTO accounts (
        customer_id, account_number, currency_code
    ) VALUES (
        test_customer_id, 'SRC-' || test_token, 'NGN'
    ) RETURNING account_id INTO source_account_id;

    INSERT INTO accounts (
        customer_id, account_number, currency_code
    ) VALUES (
        test_customer_id, 'DST-' || test_token, 'NGN'
    ) RETURNING account_id INTO destination_account_id;

    INSERT INTO accounts (
        customer_id, account_number, currency_code
    ) VALUES (
        test_customer_id, 'USD-' || test_token, 'USD'
    ) RETURNING account_id INTO foreign_currency_account_id;

    -- A transfer between accounts in different currencies must be rejected.
    BEGIN
        INSERT INTO transactions (
            source_account_id, destination_account_id,
            transaction_type, amount, currency_code
        ) VALUES (
            source_account_id, foreign_currency_account_id,
            'TRANSFER', 10.00, 'NGN'
        );
        RAISE EXCEPTION USING ERRCODE = 'PZ001',
            MESSAGE = 'FAIL: cross-currency transfer was accepted';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = 'PZ001' THEN RAISE; END IF;
        IF SQLSTATE IN ('P0001', '23514') THEN
            RAISE NOTICE 'PASS: cross-currency transfer rejected';
        ELSE
            RAISE;
        END IF;
    END;

    -- A completed transaction with unequal debit and credit totals must fail.
    INSERT INTO transactions (
        source_account_id, destination_account_id,
        transaction_type, amount, currency_code
    ) VALUES (
        source_account_id, destination_account_id,
        'TRANSFER', 100.00, 'NGN'
    ) RETURNING transaction_id INTO test_transaction_id;

    INSERT INTO ledger_entries (
        transaction_id, account_id, direction, amount, currency_code
    ) VALUES
        (test_transaction_id, source_account_id, 'DEBIT', 100.00, 'NGN'),
        (test_transaction_id, destination_account_id, 'CREDIT', 50.00, 'NGN');

    BEGIN
        UPDATE transactions
        SET status = 'COMPLETED'
        WHERE transaction_id = test_transaction_id;
        RAISE EXCEPTION USING ERRCODE = 'PZ001',
            MESSAGE = 'FAIL: unbalanced completed transaction was accepted';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = 'PZ001' THEN RAISE; END IF;
        IF SQLSTATE IN ('P0001', '23514') THEN
            RAISE NOTICE 'PASS: unbalanced completed transaction rejected';
        ELSE
            RAISE;
        END IF;
    END;

    -- Equal debit and credit totals must allow completion.
    INSERT INTO transactions (
        source_account_id, destination_account_id,
        transaction_type, amount, currency_code
    ) VALUES (
        source_account_id, destination_account_id,
        'TRANSFER', 100.00, 'NGN'
    ) RETURNING transaction_id INTO test_transaction_id;

    INSERT INTO ledger_entries (
        transaction_id, account_id, direction, amount, currency_code
    ) VALUES
        (test_transaction_id, source_account_id, 'DEBIT', 100.00, 'NGN'),
        (test_transaction_id, destination_account_id, 'CREDIT', 100.00, 'NGN');

    UPDATE transactions
    SET status = 'COMPLETED'
    WHERE transaction_id = test_transaction_id;

    RAISE NOTICE 'PASS: balanced completed transaction accepted';
END $$;

ROLLBACK;
