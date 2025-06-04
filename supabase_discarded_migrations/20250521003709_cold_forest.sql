/*
  # Update program display and prediction logic

  1. Changes
    - Add function to check if program is available for prediction
    - Add trigger to validate prediction timing
    - Update RLS policies to allow predictions for today's programs

  2. Security
    - Maintain existing RLS policies
    - Add date-based validation
*/

-- Create function to check if program is available
CREATE OR REPLACE FUNCTION is_program_available(program_air_date timestamptz)
RETURNS boolean AS $$
BEGIN
  -- Allow prediction if program airs today
  RETURN DATE_TRUNC('day', program_air_date) = DATE_TRUNC('day', NOW());
END;
$$ LANGUAGE plpgsql;

-- Create function to validate prediction timing
CREATE OR REPLACE FUNCTION validate_prediction()
RETURNS TRIGGER AS $$
DECLARE
  program_air_date timestamptz;
BEGIN
  -- Get program air date
  SELECT air_date INTO program_air_date
  FROM programs
  WHERE id = NEW.program_id;

  -- Check if prediction is allowed
  IF NOT is_program_available(program_air_date) THEN
    RAISE EXCEPTION 'Les pronostics ne sont autorisés que pour les programmes du jour';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for prediction validation
CREATE TRIGGER before_prediction_insert
  BEFORE INSERT ON predictions
  FOR EACH ROW
  EXECUTE FUNCTION validate_prediction();

-- Update insert policy to include date restriction
DROP POLICY IF EXISTS "Users can insert their own predictions" ON predictions;
CREATE POLICY "Users can insert their own predictions"
  ON predictions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM programs p
      WHERE p.id = program_id
      AND is_program_available(p.air_date)
    )
  );