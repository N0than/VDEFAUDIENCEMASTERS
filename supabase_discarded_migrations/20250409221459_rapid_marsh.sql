/*
  # Add view for active players count

  1. Changes
    - Create view to calculate number of active players
    - Active player defined as having at least one scored prediction
    - Add proper indexes for performance

  2. Security
    - Grant access to authenticated users
*/

-- Create view for active players count
CREATE VIEW public.active_players_count AS
SELECT COUNT(DISTINCT user_id) as count
FROM public.predictions_with_accuracy
WHERE calculated_score > 0;

-- Grant access to the view
GRANT SELECT ON public.active_players_count TO authenticated;

-- Add index to improve performance
CREATE INDEX IF NOT EXISTS idx_predictions_calculated_score 
ON public.predictions(calculated_score);