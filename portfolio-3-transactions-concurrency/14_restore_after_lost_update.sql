-- Restore the P3 demo sender after the intentional lost-update demonstration.
-- Run after capturing the lost-update result, connected to Kaizii_MFB.

UPDATE public.accounts
SET balance = 48750.00
WHERE account_number = 'P3-DEMO-FROM-0001'
RETURNING account_number, balance;
