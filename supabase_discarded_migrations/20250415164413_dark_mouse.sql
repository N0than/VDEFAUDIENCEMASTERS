/*
  # Update weekly leaderboard ordering

  1. Changes
    - Drop existing weekly leaderboard view
    - Recreate view with explicit descending order by total_score
    - Maintain secondary sorting by precision_score

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing view
DROP VIEW IF EXISTS public.weekly_leaderboard;

-- Create improved view for weekly leaderboard with explicit ordering
CREATE VIEW public.weekly_leaderboard AS
SELECT 
  user_id,
  username,
  avatar_url,
  total_score,
  precision_score,
  rank,
  predictions_count
FROM public.weekly_user_rankings
ORDER BY total_score DESC, precision_score DESC;

-- Grant access to the view
GRANT SELECT ON public.weekly_leaderboard TO authenticated;