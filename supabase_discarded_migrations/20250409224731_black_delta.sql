/*
  # Add predictions with accuracy view

  1. Changes
    - Create view to calculate predictions with accuracy
    - Include real audience and calculated metrics
    - Add proper indexes for performance

  2. Security
    - Grant access to authenticated users
*/

-- Create view for predictions with accuracy
CREATE VIEW public.predictions_with_accuracy AS
SELECT 
  p.id as prediction_id,
  p.user_id,
  p.program_id,
  p.predicted_audience,
  pr.real_audience,
  p.calculated_accuracy,
  p.calculated_score
FROM public.predictions p
JOIN public.programs pr ON p.program_id = pr.id;

-- Grant access to the view
GRANT SELECT ON public.predictions_with_accuracy TO authenticated;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_predictions_user_id ON public.predictions(user_id);
CREATE INDEX IF NOT EXISTS idx_predictions_program_id ON public.predictions(program_id);
CREATE INDEX IF NOT EXISTS idx_predictions_real_audience ON public.predictions(real_audience);