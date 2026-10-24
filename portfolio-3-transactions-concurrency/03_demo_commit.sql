-- Portfolio 3 / Kaizii MFB
-- First committed transfer between the isolated P3 demo accounts.
-- Run connected to Kaizii_MFB. Run this demonstration once.

BEGIN;

SELECT public.p3_transfer_funds(
    'P3-DEMO-FROM-0001',
    'P3-DEMO-TO-0001',
    1000.00,
    'P3-COMMIT-001'
) AS transaction_id;

COMMIT;
