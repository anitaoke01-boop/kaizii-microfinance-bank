-- Portfolio 3 / Kaizii MFB
-- Run this same read-only transaction in Sessions A and B before either session updates.
-- Both sessions should read 48750.00. Leave both transactions open.

BEGIN;

SELECT balance
FROM public.accounts
WHERE account_number = 'P3-DEMO-FROM-0001';
