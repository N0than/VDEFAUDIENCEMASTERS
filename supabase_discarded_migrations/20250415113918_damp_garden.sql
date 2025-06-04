/*
  # Update weekly leaderboard to use last 7 days

  1. Changes
    - Drop existing weekly leaderboard view
    - Create new view using rolling 7-day window
    - Use predictions_with_accuracy view
    - Maintain existing ordering and ranking

  2. Security
    - Grant access to authenticated users
*/

-- Drop existing view
DROP VIEW IF EXISTS public.weekly_leaderboard;

-- Create improved view for weekly leaderboard using last 7 days
CREATE VIEW public.weekly_leaderboard AS
WITH weekly_scores AS (
  SELECT 
    p.user_id,
    SUM(p.calculated_score) as weekly_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as weekly_accuracy,
    COUNT(*) as predictions_count
  FROM public.predictions_with_accuracy p
  WHERE 
    p.created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
    AND p.created_at <= CURRENT_TIMESTAMP
    AND p.calculated_score IS NOT NULL
    AND p.calculated_accuracy IS NOT NULL
  GROUP BY p.user_id
  HAVING SUM(p.calculated_score) > 0
),
ranked_users AS (
  SELECT 
    ws.*,
    pr.username,
    pr.avatar_url,
    ROW_NUMBER() OVER (
      ORDER BY 
        ws.weekly_score DESC,
        ws.weekly_accuracy DESC,
        pr.created_at ASC
    ) as weekly_rank
  FROM weekly_scores ws
  JOIN public.profiles pr ON pr.id = ws.user_id
)
SELECT 
  user_id,
  username,
  avatar_url,
  weekly_score as total_score,
  weekly_accuracy as precision_score,
  weekly_rank as rank,
  predictions_count
FROM ranked_users
ORDER BY rank ASC;

-- Grant access to the view
GRANT SELECT ON public.weekly_leaderboard TO authenticated;