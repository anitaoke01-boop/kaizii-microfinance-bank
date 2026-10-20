
-- Portfolio 1: Kaizii Microfinance Bank
-- Database schema for PostgreSQL
-- Run this script only against a fresh database.

CREATE TABLE customers (
    customer_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(30) UNIQUE NOT NULL,
    customer_type VARCHAR(20) NOT NULL
        CHECK (customer_type IN ('INDIVIDUAL', 'MERCHANT')),
    country_code CHAR(2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE accounts (
    account_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    account_number VARCHAR(34) UNIQUE NOT NULL,
    account_type VARCHAR(20) NOT NULL DEFAULT 'CUSTOMER'
        CHECK (account_type IN ('CUSTOMER', 'CLEARING')),
    currency_code CHAR(3) NOT NULL DEFAULT 'NGN',
    balance NUMERIC(18,2) NOT NULL DEFAULT 0
        CHECK (balance >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_account_owner_type CHECK (
        (account_type = 'CUSTOMER' AND customer_id IS NOT NULL)
        OR
        (account_type = 'CLEARING' AND customer_id IS NULL)
    )
);

CREATE TABLE kyc_records (
    kyc_record_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    id_type VARCHAR(50) NOT NULL,
    verification_status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    submitted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMP,
    CONSTRAINT chk_kyc_verified_at CHECK (
        verification_status <> 'PENDING' OR verified_at IS NULL
    )
);

CREATE TABLE beneficiaries (
    beneficiary_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    beneficiary_name VARCHAR(150) NOT NULL,
    bank_name VARCHAR(150) NOT NULL,
    country_code CHAR(2) NOT NULL,
    account_number VARCHAR(34) NOT NULL,
    currency_code CHAR(3) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE linked_accounts (
    linked_account_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    bank_name VARCHAR(150) NOT NULL,
    country_code CHAR(2) NOT NULL,
    account_number VARCHAR(34) NOT NULL,
    account_name VARCHAR(150),
    currency_code CHAR(3) NOT NULL,
    verification_status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE cards (
    card_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES accounts(account_id),
    last_four CHAR(4) NOT NULL CHECK (last_four ~ '^[0-9]{4}$'),
    card_type VARCHAR(20) NOT NULL DEFAULT 'VIRTUAL',
    card_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (card_status IN ('ACTIVE', 'BLOCKED', 'EXPIRED', 'CANCELLED')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transactions (
    transaction_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idempotency_key VARCHAR(100) UNIQUE,
    source_account_id INTEGER REFERENCES accounts(account_id),
    destination_account_id INTEGER REFERENCES accounts(account_id),
    card_id INTEGER REFERENCES cards(card_id),
    transaction_type VARCHAR(30) NOT NULL
        CHECK (transaction_type IN (
            'DEPOSIT', 'WITHDRAWAL', 'TRANSFER', 'CARD_PURCHASE', 'REVERSAL'
        )),
    amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    currency_code CHAR(3) NOT NULL DEFAULT 'NGN',
    purchase_amount NUMERIC(18,2) CHECK (
        purchase_amount IS NULL OR purchase_amount > 0
    ),
    purchase_currency_code CHAR(3),
    country_code CHAR(2),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED')),
    reversal_of_transaction_id INTEGER REFERENCES transactions(transaction_id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ledger_entries (
    entry_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id INTEGER NOT NULL REFERENCES transactions(transaction_id),
    account_id INTEGER NOT NULL REFERENCES accounts(account_id),
    direction VARCHAR(10) NOT NULL CHECK (direction IN ('DEBIT', 'CREDIT')),
    amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    currency_code CHAR(3) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ledger_transaction_account_direction
        UNIQUE (transaction_id, account_id, direction)
);

CREATE TABLE fraud_flags (
    flag_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id INTEGER NOT NULL REFERENCES transactions(transaction_id),
    reason VARCHAR(255) NOT NULL,
    review_status VARCHAR(20) NOT NULL DEFAULT 'OPEN'
        CHECK (review_status IN ('OPEN', 'UNDER_REVIEW', 'CLEARED', 'CONFIRMED')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
