/*
  # Update weekly leaderboard to use predictions_with_accuracy_weekly view

  1. Changes
    - Drop existing weekly leaderboard view
    - Create new view using predictions_with_accuracy_weekly
    - Add proper ranking calculation
    - Maintain existing ordering

  2. Security
    - Grant access to authenticated users
*/

-- Drop existing view
DROP VIEW IF EXISTS public.weekly_leaderboard;

-- Create improved view for weekly leaderboard
CREATE VIEW public.weekly_leaderboard AS
WITH ranked_users AS (
  SELECT 
    p.user_id,
    pr.username,
    pr.avatar_url,
    SUM(p.calculated_score) as total_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as precision_score,
    COUNT(*) as predictions_count,
    ROW_NUMBER() OVER (
      ORDER BY 
        SUM(p.calculated_score) DESC,
        AVG(p.calculated_accuracy) DESC,
        MIN(pr.created_at) ASC
    ) as rank
  FROM public.predictions_with_accuracy_weekly p
  JOIN public.profiles pr ON pr.id = p.user_id
  WHERE 
    p.calculated_score IS NOT NULL 
    AND p.calculated_accuracy IS NOT NULL
  GROUP BY 
    p.user_id,
    pr.username,
    pr.avatar_url
  HAVING SUM(p.calculated_score) > 0
)
SELECT 
  user_id,
  username,
  avatar_url,
  total_score,
  precision_score,
  rank,
  predictions_count
FROM ranked_users
ORDER BY rank ASC;

-- Grant access to the view
GRANT SELECT ON public.weekly_leaderboard TO authenticated;