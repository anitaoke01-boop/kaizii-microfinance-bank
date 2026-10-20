# Normalisation

## Starting with an unnormalised statement

Imagine storing a customer’s statement in one table:

| customer_id | customer_name | email | account_number | id_types | transactions |
|---|---|---|---|---|---|
| 101 | Anita Okezie | anita@example.test | KZ-001 | NIN, Passport | Deposit ₦5,000; Transfer ₦1,000 |

This design puts multiple ID types and transactions in single cells. Customer details are also repeated on every statement row. Finding one transaction or changing an email could require editing several values.

## First Normal Form

First normal form (1NF) requires each cell to contain one value, with no lists of values in a column. I would store each transaction and each KYC submission as a separate row. For example, an NIN submission and a Passport submission would be separate KYC records, and each transaction would have its own transaction row.

This removes the lists, but customer and account details may still be repeated across many transaction rows.

## Second Normal Form

Second normal form (2NF) requires every non-key column to depend on the whole primary key, not just part of a composite key. In a statement table keyed by `(account_id, transaction_id)`, the customer’s name depends on the customer, and the account number depends on the account. Neither depends on the whole statement-row key.

The design separates those facts into `customers`, `accounts`, and `transactions`. Each table now describes one kind of entity. The final tables use single-column primary keys, so there are no partial dependencies on part of a composite primary key.

## Third Normal Form

Third normal form (3NF) requires non-key columns to depend on the key, not on another non-key column. Customer details belong in `customers`; they are not repeated in `accounts` or `transactions`. KYC status belongs in `kyc_records`, while transaction type, amount, and status belong in `transactions`.

The other entities are separated as well. Cards, beneficiaries, customers’ linked external bank accounts, ledger entries, and fraud flags each have their own tables. This reduces repeated data and the risk of inconsistent updates.

## How the final tables match the ER diagram

The final model has nine tables:

- `customers` has one-to-many relationships with `kyc_records`, `accounts`, `beneficiaries`, and `linked_accounts`.
- `accounts` has one-to-many relationships with `cards` and `ledger_entries`. Transactions refer to accounts through their source and destination account foreign keys.
- `transactions` has one-to-many relationships with `ledger_entries` and `fraud_flags`.
- A reversal in `transactions` refers to its original transaction through a self-referencing foreign key.

The final ER diagram should show these same tables and foreign-key relationships.

## Deliberate denormalisation and its risks

`accounts.balance` is stored even though it can be calculated from ledger entries. This makes balance lookups convenient, but the stored balance could disagree with the ledger. The application must update the balance and ledger entries atomically, and a reconciliation query should compare them.

The transaction-level amount is stored in `transactions.amount`, while each financial posting has its own amount in `ledger_entries`. `transactions.amount` describes the transaction; ledger entries describe its account-level effects. For applicable transactions, validation should ensure the postings match the transaction amount as well as balance each other. The current database check enforces debit-credit balance, but does not yet verify that the postings match `transactions.amount`.

The `linked_accounts.account_name` value is stored for display. It may become outdated if the external bank account name changes. It should be refreshed when the linked account is re-verified. The current design does not store `ledger_entries.balance_after`; adding it could speed statement generation, but it would also require careful updates and reconciliation to prevent stale running balances.