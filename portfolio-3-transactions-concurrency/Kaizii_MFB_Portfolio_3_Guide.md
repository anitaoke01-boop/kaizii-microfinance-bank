# Portfolio 3: Kaizii MFB Transactions and Concurrency

## Purpose and source

This is a Kaizii MFB adaptation of the supplied MIT 8103 self-study guide and NairaPay examples. The NairaPay SQL is a reference for the kinds of work to demonstrate; it is not Kaizii's schema and must not be pasted unchanged. The official assessment brief and lecturer instructions take priority for required evidence and marking criteria.

The work uses a separate set of fictitious `P3-` demo accounts. Do not reset, truncate, or delete the existing Portfolio 2 sample data.

## Kaizii schema facts used for this adaptation

- `accounts.account_id` and `transactions.transaction_id` are integers.
- `accounts` stores `account_number`, `currency_code`, `balance`, and `status`.
- `transactions` stores `idempotency_key`, `source_account_id`, `destination_account_id`, `transaction_type`, `amount`, `currency_code`, `status`, and `created_at`.
- `ledger_entries` stores `transaction_id`, `account_id`, `direction`, `amount`, `currency_code`, and `created_at`.
- Kaizii has no `transactions.txn_type`, `transactions.reference`, `transactions.completed_at`, or `ledger_entries.balance_after`. The adapted SQL does not use those columns.
- The database already has account-currency and transfer-currency safeguards and deferred ledger-balance triggers.

## Work plan

### Step 1 — Portfolio folder

The `portfolio-3-transactions-concurrency` folder is in the project. Its `output/` folder is for saved query and stress-test outputs; `screenshots/` is for evidence images.

### Step 2 — Check the database before adding demo data

This read-only check has already been run in pgAdmin against `Kaizii_MFB`. It returned 5,000 customers, 5,000 accounts, 202,000 transactions, 404,000 ledger entries, and zero existing `P3-` demo accounts or transactions. The database also has the four expected currency and ledger integrity triggers.

The repeatable read-only SQL is in `00_check_prerequisites.sql`. Do not run a seed script from the NairaPay bundle.

### Step 3 — Install the safe transfer function

Review `01_transfer_function.sql`, then run the whole file in pgAdmin while connected to `Kaizii_MFB`. It creates only a function named `public.p3_transfer_funds`; it does not move money or change existing rows. The function validates inputs and account currencies, records requests by idempotency key, locks the two accounts in ascending account ID order, checks the sender's balance, updates both balances, writes matching debit and credit ledger entries, and marks the transaction complete.

This function follows Kaizii's actual integer IDs, `transaction_type`, `created_at`, `DEBIT`/`CREDIT` ledger format, and existing deferred integrity checks. It does not use a balance-after column.

### Step 4 — Create isolated demo accounts

Next, create two clearly fictitious Kaizii customers and accounts with reserved `P3-` account numbers. The setup will be additive and rerunnable; it must not alter existing customer or account balances. We will check the proposed setup SQL before running it.

### Step 5 — Demonstrate transaction behaviour

Using only the demo accounts, demonstrate a committed transfer, a rolled-back transfer, an insufficient-funds failure, and a repeated idempotency key. Capture the actual pgAdmin results; do not invent output.

### Step 6 — Demonstrate concurrency

Use separate pgAdmin query tabs (sessions) and only the `P3-` demo accounts to show a row-lock wait, the selected isolation behaviour, and a deadlock. The deliberately unordered locking example will be kept in a separate demonstration script and used only with demo accounts.

### Step 7 — Stress test and integrity check

Use PostgreSQL's `pgbench` against only the demo accounts. Compare the safe ordered-lock function with the deliberately unordered demonstration, then run the Kaizii integrity queries. Save the actual command output under `output/`. Do not run stress tests against normal Kaizii accounts.

### Step 8 — One custom concurrency experiment

Choose one additional experiment, such as setting a short `lock_timeout` in a demo session, and explain what happened using your own observed output.

### Step 9 — Explain and collect evidence

Write a short analysis and README describing the method, actual results, limitations, and what you learned. Save screenshots in `screenshots/` using the course naming convention. Include the required AI-use declaration if applicable.

### Step 10 — Commit and push

Review the files and screenshots, then commit the Portfolio 3 folder as its own meaningful step and push to the existing GitHub repository. Do not force-push or replace remote history.

## Progress

Steps 1 through 4 are complete. The safe transfer function and two P3 demo accounts are set up. The committed-transfer demonstration in Step 5 is complete and verified: its 1,000 NGN debit and credit were visible. The rollback demonstration was run, and its read-only verification is in `05_verify_rollback.sql`. The insufficient-funds demonstration and its verification are in `06_demo_insufficient_funds.sql`. The idempotency demonstration is in `07_demo_idempotency.sql`. Next, run `08_demo_savepoint.sql` in pgAdmin with `Kaizii_MFB` selected. It performs a 100 NGN transfer after a savepoint, rolls back to that savepoint, commits the outer transaction, and displays balances plus the saved transaction count. Expected: balances unchanged from the idempotency result and zero saved rows for the savepoint key. The transaction-behaviour demonstrations are complete. Step 6 starts with a row-lock wait: open two separate pgAdmin Query Tool sessions connected to `Kaizii_MFB`. Run `09_row_lock_session_a.sql` in Session A and leave it open. In Session B, run `10_row_lock_session_b.sql`; it should wait for the same P3 demo account lock. Once the wait is visible, commit Session A, then confirm Session B finishes and commit Session B. Do not use a normal Kaizii account.
