/*
  # Add genre-based leaderboard view

  1. Changes
    - Create view for genre-specific rankings
    - Calculate scores and accuracy per genre
    - Include user profile information
    - Add proper ordering

  2. Security
    - Grant access to authenticated users
*/

-- Create view for genre-based rankings
CREATE VIEW public.classement_par_genre AS
WITH genre_scores AS (
  SELECT 
    p.user_id,
    pr.genre,
    SUM(p.calculated_score) as total_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as precision_score,
    COUNT(*) as predictions_count
  FROM public.predictions p
  JOIN public.programs pr ON p.program_id = pr.id
  WHERE 
    p.calculated_score IS NOT NULL 
    AND p.calculated_accuracy IS NOT NULL
    AND pr.genre IS NOT NULL
  GROUP BY p.user_id, pr.genre
  HAVING SUM(p.calculated_score) > 0
),
ranked_users AS (
  SELECT 
    gs.*,
    pf.username,
    pf.avatar_url,
    ROW_NUMBER() OVER (
      PARTITION BY gs.genre
      ORDER BY 
        gs.total_score DESC,
        gs.precision_score DESC
    ) as rank
  FROM genre_scores gs
  JOIN public.profiles pf ON pf.id = gs.user_id
)
SELECT 
  gen_random_uuid() as id,
  user_id,
  username,
  avatar_url,
  genre,
  total_score,
  precision_score,
  rank,
  predictions_count,
  NOW() as updated_at
FROM ranked_users
ORDER BY genre, rank ASC;

-- Grant access to the view
GRANT SELECT ON public.classement_par_genre TO authenticated;