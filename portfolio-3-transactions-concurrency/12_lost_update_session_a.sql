-- Lost-update experiment, Session A.
-- Use only after Sessions A and B both read 48750.00.
-- This stale-value write is intentional for the demonstration.

UPDATE public.accounts
SET balance = 47750.00
WHERE account_number = 'P3-DEMO-FROM-0001';

COMMIT;
