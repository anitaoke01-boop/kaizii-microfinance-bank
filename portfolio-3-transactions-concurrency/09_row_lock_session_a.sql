-- Portfolio 3 / Kaizii MFB
-- Session A: acquire a row lock on the isolated demo sender account.
-- Run connected to Kaizii_MFB. Leave this transaction open for Session B.

BEGIN;

SELECT account_id, account_number, balance
FROM public.accounts
WHERE account_number = 'P3-DEMO-FROM-0001'
FOR UPDATE;
