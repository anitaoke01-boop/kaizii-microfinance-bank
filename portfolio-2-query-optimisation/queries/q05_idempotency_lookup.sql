-- Replace with an existing key returned by q00.
SELECT * FROM transactions
WHERE idempotency_key='P2SEED-XFER-00025000';
