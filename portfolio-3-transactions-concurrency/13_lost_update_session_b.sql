-- Lost-update experiment, Session B.
-- Use only after Session A committed the same 47750.00 stale value.
-- Session B read 48750.00 before Session A wrote; this intentionally overwrites A's value.

UPDATE public.accounts
SET balance = 47750.00
WHERE account_number = 'P3-DEMO-FROM-0001';

COMMIT;
