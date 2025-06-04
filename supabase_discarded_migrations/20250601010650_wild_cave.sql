/*
  # Fix monthly leaderboard view with CASCADE

  1. Changes
    - Drop view with CASCADE to handle dependencies
    - Recreate view with proper ranking logic
    - Add snapshot table if it doesn't exist

  2. Security
    - Grant proper access to authenticated users
*/

-- Drop existing view with CASCADE to handle dependencies
DROP VIEW IF EXISTS public.classement_mois_en_cours CASCADE;

-- Create view for historical monthly rankings
CREATE VIEW public.classement_mois_en_cours AS
WITH current_month AS (
  SELECT 
    date_trunc('month', CURRENT_TIMESTAMP) as month_start,
    date_trunc('month', CURRENT_TIMESTAMP) + INTERVAL '1 month - 1 second' as month_end
),
monthly_scores AS (
  SELECT 
    p.user_id,
    date_trunc('month', p.created_at) as month,
    SUM(p.calculated_score + COALESCE(p.calculated_bonus_score, 0)) as total_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as precision_score,
    COUNT(*) as predictions_count
  FROM public.predictions_with_accuracy3 p
  GROUP BY p.user_id, date_trunc('month', p.created_at)
  HAVING SUM(p.calculated_score + COALESCE(p.calculated_bonus_score, 0)) > 0
),
previous_ranks AS (
  SELECT 
    user_id,
    month,
    total_score,
    precision_score,
    predictions_count,
    ROW_NUMBER() OVER (
      PARTITION BY month
      ORDER BY total_score DESC, precision_score DESC
    ) as rank
  FROM monthly_scores
),
ranked_users AS (
  SELECT 
    gen_random_uuid() as id,
    ms.*,
    pr.username,
    pr.avatar_url,
    ROW_NUMBER() OVER (
      PARTITION BY ms.month
      ORDER BY 
        ms.total_score DESC,
        ms.precision_score DESC,
        pr.created_at ASC
    ) as rank,
    COALESCE(prev.rank, 0) as previous_rank,
    CASE 
      WHEN prev.rank IS NULL THEN 'new'
      WHEN ROW_NUMBER() OVER (
        PARTITION BY ms.month
        ORDER BY 
          ms.total_score DESC,
          ms.precision_score DESC,
          pr.created_at ASC
      ) < prev.rank THEN 'up'
      WHEN ROW_NUMBER() OVER (
        PARTITION BY ms.month
        ORDER BY 
          ms.total_score DESC,
          ms.precision_score DESC,
          pr.created_at ASC
      ) > prev.rank THEN 'down'
      ELSE NULL
    END as trend,
    CASE 
      WHEN prev.rank IS NULL THEN NULL
      ELSE ABS(
        ROW_NUMBER() OVER (
          PARTITION BY ms.month
          ORDER BY 
            ms.total_score DESC,
            ms.precision_score DESC,
            pr.created_at ASC
        ) - prev.rank
      )
    END as rank_change
  FROM monthly_scores ms
  JOIN public.profiles pr ON pr.id = ms.user_id
  LEFT JOIN previous_ranks prev ON 
    prev.user_id = ms.user_id AND
    prev.month = ms.month - INTERVAL '1 month'
)
SELECT 
  id,
  user_id,
  month,
  total_score,
  precision_score,
  rank,
  NOW() as updated_at,
  username,
  avatar_url,
  predictions_count,
  previous_rank,
  trend,
  rank_change
FROM ranked_users
ORDER BY month DESC, rank ASC;

-- Create snapshot table for previous month's rankings if it doesn't exist
CREATE TABLE IF NOT EXISTS public.classement_mois_en_cours_snapshot (
  user_id uuid PRIMARY KEY,
  previous_rank integer,
  total_score integer,
  precision_score numeric,
  predictions_count integer,
  updated_at timestamp without time zone DEFAULT now()
);

-- Recreate the dependent view
CREATE VIEW public.monthly_user_rankings_previous AS
WITH previous_month AS (
  SELECT 
    date_trunc('month', CURRENT_TIMESTAMP - INTERVAL '1 month') as month_start,
    date_trunc('month', CURRENT_TIMESTAMP) - INTERVAL '1 second' as month_end
)
SELECT 
  user_id,
  month,
  previous_rank,
  total_score,
  precision_score,
  predictions_count,
  updated_at
FROM public.classement_mois_en_cours
WHERE month >= (SELECT month_start FROM previous_month)
  AND month <= (SELECT month_end FROM previous_month);

-- Grant access to the views
GRANT SELECT ON public.classement_mois_en_cours TO authenticated;
GRANT SELECT ON public.monthly_user_rankings_previous TO authenticated;