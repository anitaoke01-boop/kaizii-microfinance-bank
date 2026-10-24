-- Portfolio 3 / Kaizii MFB
-- Session B: request the row lock held by Session A; this SELECT should wait.
-- Run in a separate Query Tool session connected to Kaizii_MFB.

BEGIN;

SELECT account_id, account_number, balance
FROM public.accounts
WHERE account_number = 'P3-DEMO-FROM-0001'
FOR UPDATE;
