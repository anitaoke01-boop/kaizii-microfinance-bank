-- Q8: Net movement including reversals.
-- Counts completed transfers and transfers later marked REVERSED, then subtracts
-- completed reversal transactions linked to an original TRANSFER with status REVERSED
-- and matching currency.
-- Grouped by currency_code to prevent cross-currency summation.
WITH eligible_transactions AS (
    SELECT t.transaction_id,
           t.transaction_type,
           t.status,
           t.amount,
           t.currency_code,
           t.created_at,
           t.reversal_of_transaction_id,
           CASE
               WHEN t.transaction_type = 'REVERSAL'
                AND t.status = 'COMPLETED'
                AND t.reversal_of_transaction_id IS NOT NULL
                AND EXISTS (
                    SELECT 1
                    FROM transactions orig
                    WHERE orig.transaction_id = t.reversal_of_transaction_id
                      AND orig.transaction_type = 'TRANSFER'
                      AND orig.status = 'REVERSED'
                      AND orig.currency_code = t.currency_code
                ) THEN true
               ELSE false
           END AS is_valid_linked_reversal
    FROM transactions t
    WHERE t.created_at >= now() - interval '90 days'
      AND t.transaction_type IN ('TRANSFER', 'REVERSAL')
)
SELECT currency_code,
       count(*) FILTER (WHERE transaction_type = 'TRANSFER' AND status = 'COMPLETED')
         AS transfers_still_completed,
       count(*) FILTER (WHERE transaction_type = 'TRANSFER' AND status = 'REVERSED')
         AS transfers_later_reversed,
       coalesce(sum(amount) FILTER
         (WHERE transaction_type = 'TRANSFER' AND status IN ('COMPLETED', 'REVERSED')), 0)
         AS original_transfer_amount,
       count(*) FILTER (WHERE is_valid_linked_reversal)
         AS completed_reversals,
       coalesce(sum(amount) FILTER (WHERE is_valid_linked_reversal), 0)
         AS completed_reversal_amount,
       coalesce(sum(CASE
         WHEN transaction_type = 'TRANSFER' AND status IN ('COMPLETED', 'REVERSED') THEN amount
         WHEN is_valid_linked_reversal THEN -amount
         ELSE 0 END), 0) AS net_amount_after_reversals
FROM eligible_transactions
GROUP BY currency_code
ORDER BY currency_code;
