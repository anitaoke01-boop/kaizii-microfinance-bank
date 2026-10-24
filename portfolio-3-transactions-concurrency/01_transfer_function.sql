-- Portfolio 3 / Kaizii MFB
-- Creates the safe, ordered-lock transfer function only.
-- It does not execute a transfer or change account balances.
-- Run connected to Kaizii_MFB.

CREATE OR REPLACE FUNCTION public.p3_transfer_funds(
    p_from_account_number VARCHAR(34),
    p_to_account_number   VARCHAR(34),
    p_amount              NUMERIC,
    p_idempotency_key     VARCHAR(100)
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $function$
DECLARE
    v_from_id           INTEGER;
    v_to_id             INTEGER;
    v_from_currency     VARCHAR(3);
    v_to_currency       VARCHAR(3);
    v_first_id          INTEGER;
    v_second_id         INTEGER;
    v_from_balance      NUMERIC(18,2);
    v_from_status       VARCHAR(20);
    v_to_status         VARCHAR(20);
    v_transaction_id    INTEGER;
    v_existing_id       INTEGER;
    v_existing_from     INTEGER;
    v_existing_to       INTEGER;
    v_existing_amount   NUMERIC(18,2);
    v_existing_currency VARCHAR(3);
    v_existing_type     VARCHAR(30);
    v_existing_status   VARCHAR(20);
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'P3_INVALID_AMOUNT: amount must be greater than zero';
    END IF;

    IF p_amount <> ROUND(p_amount, 2) THEN
        RAISE EXCEPTION 'P3_INVALID_AMOUNT_PRECISION: amount must have no more than two decimal places';
    END IF;

    IF p_idempotency_key IS NULL OR BTRIM(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'P3_MISSING_IDEMPOTENCY_KEY: provide a non-empty key';
    END IF;

    SELECT account_id, currency_code
      INTO v_from_id, v_from_currency
      FROM public.accounts
     WHERE account_number = p_from_account_number;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'P3_SOURCE_ACCOUNT_NOT_FOUND';
    END IF;

    SELECT account_id, currency_code
      INTO v_to_id, v_to_currency
      FROM public.accounts
     WHERE account_number = p_to_account_number;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'P3_DESTINATION_ACCOUNT_NOT_FOUND';
    END IF;

    IF v_from_id = v_to_id THEN
        RAISE EXCEPTION 'P3_SAME_ACCOUNT: source and destination must differ';
    END IF;

    IF v_from_currency IS DISTINCT FROM v_to_currency THEN
        RAISE EXCEPTION 'P3_CURRENCY_MISMATCH: both accounts must use the same currency';
    END IF;

    -- Register the request before any balance change. A repeated key with the
    -- same completed transfer returns its original transaction ID.
    INSERT INTO public.transactions (
        idempotency_key,
        source_account_id,
        destination_account_id,
        transaction_type,
        amount,
        currency_code,
        status
    )
    VALUES (
        p_idempotency_key,
        v_from_id,
        v_to_id,
        'TRANSFER',
        p_amount,
        v_from_currency,
        'PENDING'
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING transaction_id INTO v_transaction_id;

    IF v_transaction_id IS NULL THEN
        SELECT transaction_id,
               source_account_id,
               destination_account_id,
               amount,
               currency_code,
               transaction_type,
               status
          INTO v_existing_id,
               v_existing_from,
               v_existing_to,
               v_existing_amount,
               v_existing_currency,
               v_existing_type,
               v_existing_status
          FROM public.transactions
         WHERE idempotency_key = p_idempotency_key;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'P3_RETRY_REQUEST: could not read the existing idempotency record';
        END IF;

        IF v_existing_from IS DISTINCT FROM v_from_id
           OR v_existing_to IS DISTINCT FROM v_to_id
           OR v_existing_amount IS DISTINCT FROM p_amount
           OR v_existing_currency IS DISTINCT FROM v_from_currency
           OR v_existing_type IS DISTINCT FROM 'TRANSFER'
           OR v_existing_status IS DISTINCT FROM 'COMPLETED' THEN
            RAISE EXCEPTION 'P3_IDEMPOTENCY_KEY_REUSED: key belongs to a different or incomplete transaction';
        END IF;

        RETURN v_existing_id;
    END IF;

    -- Acquire the two account row locks in a consistent order to reduce
    -- deadlocks when transfers run concurrently in opposite directions.
    v_first_id := LEAST(v_from_id, v_to_id);
    v_second_id := GREATEST(v_from_id, v_to_id);

    PERFORM account_id
      FROM public.accounts
     WHERE account_id = v_first_id
     FOR UPDATE;

    PERFORM account_id
      FROM public.accounts
     WHERE account_id = v_second_id
     FOR UPDATE;

    SELECT balance, status
      INTO v_from_balance, v_from_status
      FROM public.accounts
     WHERE account_id = v_from_id;

    SELECT status
      INTO v_to_status
      FROM public.accounts
     WHERE account_id = v_to_id;

    IF v_from_status IS DISTINCT FROM 'ACTIVE'
       OR v_to_status IS DISTINCT FROM 'ACTIVE' THEN
        RAISE EXCEPTION 'P3_ACCOUNT_NOT_ACTIVE: both accounts must be active';
    END IF;

    IF v_from_balance < p_amount THEN
        RAISE EXCEPTION 'P3_INSUFFICIENT_FUNDS';
    END IF;

    UPDATE public.accounts
       SET balance = balance - p_amount
     WHERE account_id = v_from_id;

    UPDATE public.accounts
       SET balance = balance + p_amount
     WHERE account_id = v_to_id;

    INSERT INTO public.ledger_entries (
        transaction_id, account_id, direction, amount, currency_code
    )
    VALUES
        (v_transaction_id, v_from_id, 'DEBIT',  p_amount, v_from_currency),
        (v_transaction_id, v_to_id,   'CREDIT', p_amount, v_from_currency);

    UPDATE public.transactions
       SET status = 'COMPLETED'
     WHERE transaction_id = v_transaction_id;

    RETURN v_transaction_id;
END;
$function$;
