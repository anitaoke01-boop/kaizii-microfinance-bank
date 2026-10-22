-- Portfolio 2: Kaizii Microfinance Bank
-- Sample Seed Data Script (PostgreSQL)
-- File: portfolio-2-query-optimisation/sql/00_seed_sample_data.sql
--
-- Adds fictional sample records to:
--   1. customers (5,000 records)
--   2. accounts (5,000 records)
--   3. transactions (200,000 transfers + 2,000 reversals)
--   4. ledger_entries (404,000 balanced debit/credit lines)
--
-- Safety:
--   - Wrapped in a transaction (BEGIN ... COMMIT).
--   - Refuses execution if any of the four tables already contains rows.
--   - Does NOT delete, truncate, or alter existing data.
--   - Respects all schema constraints, check constraints, and triggers.

BEGIN;

-- 1. Safety check: Abort if any target table contains data.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM customers)
       OR EXISTS (SELECT 1 FROM accounts)
       OR EXISTS (SELECT 1 FROM transactions)
       OR EXISTS (SELECT 1 FROM ledger_entries) THEN
        RAISE EXCEPTION
            'Seed stopped: customers, accounts, transactions, and ledger_entries must be empty.';
    END IF;
END
$$;

-- 2. Insert 5,000 fictional customers.
-- Fictional names, emails ending in @example.invalid, fictional phone numbers.
INSERT INTO customers (
    first_name, last_name, email, phone_number, customer_type, country_code
)
SELECT
    'Portfolio',
    'Customer ' || g.i,
    'p2seed-customer-' || lpad(g.i::text, 5, '0') || '@example.invalid',
    'P2-' || lpad(g.i::text, 8, '0'),
    CASE WHEN g.i % 10 = 0 THEN 'MERCHANT' ELSE 'INDIVIDUAL' END,
    'NG'
FROM generate_series(1, 5000) AS g(i);

-- 3. Insert 5,000 accounts (one per customer, currency NGN, opening balance 53,000.00 NGN).
-- An opening balance of 53,000.00 NGN is established before ledger entries are inserted
-- so that intermediate debit entries cannot temporarily drive account balances negative
-- and violate chk_account_balance.
INSERT INTO accounts (
    customer_id, account_number, account_type, currency_code, balance, status
)
SELECT
    c.customer_id,
    'P2-ACC-' || lpad(row_number() OVER (ORDER BY c.customer_id)::text, 10, '0'),
    'CUSTOMER',
    'NGN',
    53000.00,
    'ACTIVE'
FROM customers AS c
WHERE c.email LIKE 'p2seed-customer-%@example.invalid';

-- Temporary lookup mapping sequence numbers (0..4999) to account IDs.
CREATE TEMP TABLE p2_seed_accounts ON COMMIT DROP AS
SELECT
    account_id,
    (row_number() OVER (ORDER BY account_number)::integer - 1) AS account_no
FROM accounts
WHERE account_number LIKE 'P2-ACC-%';

-- 4. Insert 200,000 transfers with PENDING status.
-- Dates are within the last 90 days.
-- Transfers include high-value NGN transfers of 5,000 NGN (>= 4,000 NGN threshold for Q04).
-- Accounts cycle deterministically so each account sends and receives equal amounts.
INSERT INTO transactions (
    idempotency_key, source_account_id, destination_account_id,
    transaction_type, amount, currency_code, status, created_at
)
SELECT
    'P2SEED-XFER-' || lpad(g.i::text, 8, '0'),
    src.account_id,
    dst.account_id,
    'TRANSFER',
    CASE WHEN (((g.i - 1) / 5000) % 4) = 0 THEN 5000.00 ELSE 100.00 END,
    'NGN',
    'PENDING',
    now() - (((g.i - 1) % 90) * interval '1 day')
FROM generate_series(1, 200000) AS g(i)
JOIN p2_seed_accounts AS src
  ON src.account_no = ((g.i - 1) % 5000)
JOIN p2_seed_accounts AS dst
  ON dst.account_no = (g.i % 5000);

-- Temporary table capturing transfer IDs for ledger generation.
CREATE TEMP TABLE p2_seed_transfers ON COMMIT DROP AS
SELECT
    transaction_id,
    source_account_id,
    destination_account_id,
    amount,
    currency_code,
    created_at,
    substring(idempotency_key FROM 13)::integer AS transfer_no
FROM transactions
WHERE idempotency_key LIKE 'P2SEED-XFER-%';

-- 5. Insert 2,000 completed reversals linked to original transfers (for Q08).
-- Every 100th transfer has a reversal transaction referring back to the original.
INSERT INTO transactions (
    idempotency_key, source_account_id, destination_account_id,
    transaction_type, amount, currency_code, status,
    reversal_of_transaction_id, created_at
)
SELECT
    'P2SEED-REV-' || lpad(transfer_no::text, 8, '0'),
    destination_account_id,
    source_account_id,
    'REVERSAL',
    amount,
    currency_code,
    'PENDING',
    transaction_id,
    created_at
FROM p2_seed_transfers
WHERE transfer_no % 100 = 0;

-- Temporary table capturing reversal IDs for ledger generation.
CREATE TEMP TABLE p2_seed_reversals ON COMMIT DROP AS
SELECT
    transaction_id,
    source_account_id,
    destination_account_id,
    amount,
    currency_code,
    created_at
FROM transactions
WHERE idempotency_key LIKE 'P2SEED-REV-%';

-- 6. Insert balanced double-entry ledger rows for each transfer.
-- 1 CREDIT on destination account, 1 DEBIT on source account.
INSERT INTO ledger_entries (
    transaction_id, account_id, direction, amount, currency_code, created_at
)
SELECT transaction_id, destination_account_id, 'CREDIT', amount, currency_code, created_at
FROM p2_seed_transfers
UNION ALL
SELECT transaction_id, source_account_id, 'DEBIT', amount, currency_code, created_at
FROM p2_seed_transfers;

-- 7. Insert balanced double-entry ledger rows for each reversal.
INSERT INTO ledger_entries (
    transaction_id, account_id, direction, amount, currency_code, created_at
)
SELECT transaction_id, destination_account_id, 'CREDIT', amount, currency_code, created_at
FROM p2_seed_reversals
UNION ALL
SELECT transaction_id, source_account_id, 'DEBIT', amount, currency_code, created_at
FROM p2_seed_reversals;

-- 8. Complete valid ledger-backed transactions.
-- Original transfers that were reversed are marked REVERSED.
-- Other transfers and all reversal transactions are marked COMPLETED.
UPDATE transactions AS t
SET status = CASE
    WHEN x.transfer_no % 100 = 0 THEN 'REVERSED'
    ELSE 'COMPLETED'
END
FROM p2_seed_transfers AS x
WHERE t.transaction_id = x.transaction_id;

UPDATE transactions
SET status = 'COMPLETED'
WHERE idempotency_key LIKE 'P2SEED-REV-%';

-- 9. Reconcile accounts.balance to opening balance (53,000.00 NGN) plus net ledger movement.
UPDATE accounts AS a
SET balance = 53000.00 + COALESCE((
    SELECT sum(CASE
        WHEN l.direction = 'CREDIT' THEN l.amount
        WHEN l.direction = 'DEBIT' THEN -l.amount
        ELSE 0
    END)
    FROM ledger_entries AS l
    WHERE l.account_id = a.account_id
), 0)
WHERE a.account_number LIKE 'P2-ACC-%';

-- 10. Summary verification counts before commit.
SELECT
    (SELECT count(*) FROM customers
     WHERE email LIKE 'p2seed-customer-%@example.invalid') AS seed_customers,
    (SELECT count(*) FROM accounts
     WHERE account_number LIKE 'P2-ACC-%') AS seed_accounts,
    (SELECT count(*) FROM transactions
     WHERE idempotency_key LIKE 'P2SEED-XFER-%') AS seed_transfers,
    (SELECT count(*) FROM transactions
     WHERE idempotency_key LIKE 'P2SEED-REV-%') AS seed_reversals,
    (SELECT count(*) FROM ledger_entries l
     JOIN transactions t USING (transaction_id)
     WHERE t.idempotency_key LIKE 'P2SEED-%') AS seed_ledger_entries;

COMMIT;
