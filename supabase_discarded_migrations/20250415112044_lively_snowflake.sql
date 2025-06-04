/*
  # Update predictions_with_accuracy view to include created_at

  1. Changes
    - Drop existing view
    - Recreate view with created_at column
    - Keep existing columns and functionality
    - Add proper column ordering

  2. Security
    - Maintain existing permissions
*/

-- Drop existing view
DROP VIEW IF EXISTS public.predictions_with_accuracy;

-- Create improved view that includes created_at
CREATE VIEW public.predictions_with_accuracy AS
SELECT 
  p.id as prediction_id,
  p.user_id,
  p.program_id,
  p.predicted_audience,
  p.real_audience,
  p.calculated_accuracy,
  p.calculated_score,
  p.created_at
FROM public.predictions p
JOIN public.programs pr ON p.program_id = pr.id;

-- Grant access to the view
GRANT SELECT ON public.predictions_with_accuracy TO authenticated;