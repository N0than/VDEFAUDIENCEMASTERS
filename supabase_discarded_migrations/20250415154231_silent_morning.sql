/*
  # Add direct SELECT from Classement_semaine

  1. Changes
    - Drop existing weekly_leaderboard view
    - Create new view with direct SELECT
    - Add explicit SELECT * query
    
  2. Security
    - Grant access to authenticated users
*/

-- Drop existing view
DROP VIEW IF EXISTS public.weekly_leaderboard;

-- Create improved view for weekly leaderboard
CREATE VIEW public.weekly_leaderboard AS
WITH weekly_data AS (
  SELECT * FROM Classement_semaine
)
SELECT 
  user_id,
  username,
  avatar_url,
  total_score,
  precision_score,
  rank,
  predictions_count
FROM weekly_data
ORDER BY rank ASC;

-- Grant access to the view
GRANT SELECT ON public.weekly_leaderboard TO authenticated;