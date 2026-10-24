-- Portfolio 3 / Kaizii MFB
-- Demonstrates rolling back a transfer using only the P3 demo accounts.
-- Run connected to Kaizii_MFB. This transaction is intentionally cancelled.

BEGIN;

SELECT public.p3_transfer_funds(
    'P3-DEMO-FROM-0001',
    'P3-DEMO-TO-0001',
    500.00,
    'P3-ROLLBACK-001'
) AS transaction_id_to_rollback;

ROLLBACK;
