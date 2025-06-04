/*
  # Update weekly leaderboard to use Classement_semaine view

  1. Changes
    - Drop existing weekly_leaderboard view
    - Create new view that uses Classement_semaine
    - Maintain same column structure for compatibility
    
  2. Security
    - Grant access to authenticated users
*/

-- Drop existing view
DROP VIEW IF EXISTS public.weekly_leaderboard;

-- Create improved view for weekly leaderboard
CREATE VIEW public.weekly_leaderboard AS
SELECT 
  user_id,
  username,
  avatar_url,
  total_score,
  precision_score,
  rank,
  predictions_count
FROM public.Classement_semaine
ORDER BY rank ASC;

-- Grant access to the view
GRANT SELECT ON public.weekly_leaderboard TO authenticated;