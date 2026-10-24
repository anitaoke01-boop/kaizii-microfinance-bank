-- Portfolio 3 / Kaizii MFB
-- Creates two fictitious P3 demo customers and accounts.
-- Rerunning this script does not reset existing demo account balances.
-- Run connected to Kaizii_MFB.

DO $setup$
DECLARE
    v_sender_id    INTEGER;
    v_receiver_id  INTEGER;
BEGIN
    INSERT INTO public.customers (
        first_name, last_name, email, phone_number, customer_type, country_code
    )
    VALUES (
        'P3Demo', 'Sender', 'p3-demo-sender@example.invalid',
        'P3-DEMO-PHONE-001', 'INDIVIDUAL', 'NG'
    )
    ON CONFLICT (email) DO NOTHING;

    INSERT INTO public.customers (
        first_name, last_name, email, phone_number, customer_type, country_code
    )
    VALUES (
        'P3Demo', 'Receiver', 'p3-demo-receiver@example.invalid',
        'P3-DEMO-PHONE-002', 'INDIVIDUAL', 'NG'
    )
    ON CONFLICT (email) DO NOTHING;

    SELECT customer_id
      INTO v_sender_id
      FROM public.customers
     WHERE email = 'p3-demo-sender@example.invalid';

    SELECT customer_id
      INTO v_receiver_id
      FROM public.customers
     WHERE email = 'p3-demo-receiver@example.invalid';

    IF v_sender_id IS NULL OR v_receiver_id IS NULL THEN
        RAISE EXCEPTION 'P3_DEMO_CUSTOMER_SETUP_FAILED';
    END IF;

    INSERT INTO public.accounts (
        customer_id, account_number, account_type, currency_code, balance, status
    )
    VALUES
        (v_sender_id,   'P3-DEMO-FROM-0001', 'CUSTOMER', 'NGN', 50000.00, 'ACTIVE'),
        (v_receiver_id, 'P3-DEMO-TO-0001',   'CUSTOMER', 'NGN', 10000.00, 'ACTIVE')
    ON CONFLICT (account_number) DO NOTHING;

    IF NOT EXISTS (
        SELECT 1 FROM public.accounts
         WHERE account_number = 'P3-DEMO-FROM-0001'
           AND customer_id = v_sender_id
           AND account_type = 'CUSTOMER'
           AND currency_code = 'NGN'
    ) OR NOT EXISTS (
        SELECT 1 FROM public.accounts
         WHERE account_number = 'P3-DEMO-TO-0001'
           AND customer_id = v_receiver_id
           AND account_type = 'CUSTOMER'
           AND currency_code = 'NGN'
    ) THEN
        RAISE EXCEPTION 'P3_DEMO_ACCOUNT_SETUP_FAILED: reserved account numbers do not match the demo customers';
    END IF;
END;
$setup$;

-- Display only the two reserved demo accounts and their current balances.
SELECT account_number, currency_code, balance, status
FROM public.accounts
WHERE account_number IN ('P3-DEMO-FROM-0001', 'P3-DEMO-TO-0001')
ORDER BY account_number;
