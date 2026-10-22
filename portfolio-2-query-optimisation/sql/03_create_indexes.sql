-- Portfolio 2: Kaizii MFB workload indexes
-- Additive indexes selected from the captured baseline plans.
-- Run once in Kaizii_MFB before capturing plans/after.txt.
-- Existing primary-key, account-number, and idempotency indexes are not duplicated.

-- Q1: Account statement lookup and newest entries first.
CREATE INDEX IF NOT EXISTS idx_ledger_account_statement
    ON public.ledger_entries (account_id, created_at DESC, entry_id DESC)
    INCLUDE (transaction_id, direction, amount, currency_code);

-- Q2: Recent completed transfers for daily totals.
CREATE INDEX IF NOT EXISTS idx_transactions_completed_transfer_date
    ON public.transactions (created_at)
    INCLUDE (currency_code, amount)
    WHERE transaction_type = 'TRANSFER' AND status = 'COMPLETED';

-- Q3: Find a customer's accounts, then their debit entries ordered by amount.
CREATE INDEX IF NOT EXISTS idx_accounts_customer_account
    ON public.accounts (customer_id, account_id);

CREATE INDEX IF NOT EXISTS idx_ledger_debit_account_amount
    ON public.ledger_entries (account_id, amount DESC, transaction_id)
    INCLUDE (currency_code, created_at)
    WHERE direction = 'DEBIT';

-- Q4: Filter NGN debit entries by recent date and transfer value.
CREATE INDEX IF NOT EXISTS idx_ledger_ngn_debit_created
    ON public.ledger_entries (currency_code, created_at)
    INCLUDE (amount, account_id, transaction_id)
    WHERE direction = 'DEBIT';
