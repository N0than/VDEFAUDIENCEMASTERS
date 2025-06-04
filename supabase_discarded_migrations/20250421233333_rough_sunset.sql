/*
  # Fix semester rankings view

  1. Changes
    - Drop existing view if it exists
    - Recreate view with proper semester calculation
    - Add proper filtering for completed predictions
    - Add proper ordering and ranking

  2. Security
    - Grant access to authenticated users
*/

-- Drop existing view if it exists
DROP VIEW IF EXISTS public.semestre_user_rankings;

-- Create view for semester rankings
CREATE VIEW public.semestre_user_rankings AS
WITH current_semester AS (
  SELECT 
    date_trunc('month', CURRENT_DATE - INTERVAL '5 months') as semester_start,
    date_trunc('month', CURRENT_DATE) + INTERVAL '1 month - 1 second' as semester_end
),
semester_scores AS (
  SELECT 
    p.user_id,
    SUM(p.calculated_score) as semester_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as semester_accuracy,
    COUNT(*) as predictions_count
  FROM public.predictions p, current_semester s
  WHERE 
    p.created_at >= s.semester_start
    AND p.created_at <= s.semester_end
    AND p.calculated_score IS NOT NULL
    AND p.calculated_accuracy IS NOT NULL
  GROUP BY p.user_id
  HAVING SUM(p.calculated_score) > 0
),
ranked_users AS (
  SELECT 
    ss.*,
    pr.username,
    pr.avatar_url,
    ROW_NUMBER() OVER (
      ORDER BY 
        ss.semester_score DESC,
        ss.semester_accuracy DESC,
        pr.created_at ASC
    ) as semester_rank
  FROM semester_scores ss
  JOIN public.profiles pr ON pr.id = ss.user_id
)
SELECT 
  user_id,
  username,
  avatar_url,
  semester_score as total_score,
  semester_accuracy as precision_score,
  semester_rank as rank,
  predictions_count
FROM ranked_users
ORDER BY rank ASC;

-- Grant access to the view
GRANT SELECT ON public.semestre_user_rankings TO authenticated;