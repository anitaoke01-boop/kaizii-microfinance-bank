-- =====================================================================
-- Portfolio 2: Planner Settings & Experiments (Kaizii MFB)
-- File: portfolio-2-query-optimisation/sql/05_planner_experiments.sql
--
-- Read-only queries for inspecting environment settings and table statistics.
-- None of these commands modify table data or permanently change settings.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Part A: Environment & Planner Cost Constants
-- Run one at a time in pgAdmin to record your values for performance-analysis.md
-- ---------------------------------------------------------------------
SHOW server_version;
SHOW block_size;           -- Page size in bytes (typically 8192)
SHOW shared_buffers;       -- Buffer pool memory allocated to Postgres
SHOW work_mem;             -- Memory used for internal sort / hash operations
SHOW seq_page_cost;        -- Planner's estimate for disk page fetch in order (default 1.0)
SHOW random_page_cost;     -- Planner's estimate for non-sequential disk page fetch (default 4.0)
SHOW cpu_tuple_cost;       -- Planner's estimate for processing each tuple (default 0.01)

-- ---------------------------------------------------------------------
-- Part B: Data Volume & Physical Storage Footprint
-- Shows table and index sizes along with pg_class statistics.
-- ---------------------------------------------------------------------
SELECT c.relname,
       c.relkind,                                  -- 'r' = table, 'i' = index
       c.relpages                AS pages_8kb,
       c.reltuples::bigint       AS estimated_rows,
       pg_size_pretty(pg_relation_size(c.oid)) AS size
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind IN ('r', 'i')
ORDER BY pg_relation_size(c.oid) DESC
LIMIT 15;

-- ---------------------------------------------------------------------
-- Part C: Check distribution of accounts.status
-- Checks value counts to determine if a selective (rare) vs common value exists.
-- ---------------------------------------------------------------------
SELECT status,
       count(*) AS account_count,
       round(count(*) * 100.0 / sum(count(*)) OVER (), 2) AS percentage
FROM accounts
GROUP BY status;

-- ---------------------------------------------------------------------
-- Part D: Alternative selectivity distributions in Kaizii MFB
-- If accounts.status is 100% ACTIVE, these show true common vs rare distributions:
-- ---------------------------------------------------------------------
-- 1. transactions.transaction_type (TRANSFER ~99% vs REVERSAL ~1%)
SELECT transaction_type,
       count(*) AS txn_count,
       round(count(*) * 100.0 / sum(count(*)) OVER (), 2) AS percentage
FROM transactions
GROUP BY transaction_type;

-- 2. transactions.status (COMPLETED ~98% vs REVERSED ~2%)
SELECT status,
       count(*) AS status_count,
       round(count(*) * 100.0 / sum(count(*)) OVER (), 2) AS percentage
FROM transactions
GROUP BY status;
