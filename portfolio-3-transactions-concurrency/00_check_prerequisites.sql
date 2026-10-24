-- Portfolio 3 / Kaizii MFB
-- Read-only prerequisite check. Run connected to Kaizii_MFB.
-- This does not insert, update, or delete anything.

SELECT
    current_database() AS database_name,
    (SELECT COUNT(*) FROM public.customers) AS customers,
    (SELECT COUNT(*) FROM public.accounts) AS accounts,
    (SELECT COUNT(*) FROM public.transactions) AS transactions,
    (SELECT COUNT(*) FROM public.ledger_entries) AS ledger_entries,
    (SELECT COUNT(*) FROM public.accounts
     WHERE account_number LIKE 'P3-%') AS existing_p3_demo_accounts,
    (SELECT COUNT(*) FROM public.transactions
     WHERE idempotency_key LIKE 'P3-%') AS existing_p3_transactions;
