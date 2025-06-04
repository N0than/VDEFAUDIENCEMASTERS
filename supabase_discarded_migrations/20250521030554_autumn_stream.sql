/*
  # Update prediction time limit to 22:00

  1. Changes
    - Update is_prediction_allowed function to allow predictions until 22:00
    - Keep existing validation logic
    - Update function comments

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing function
DROP FUNCTION IF EXISTS is_prediction_allowed(timestamptz);

-- Create updated function with new time limit
CREATE OR REPLACE FUNCTION is_prediction_allowed(program_air_date timestamptz)
RETURNS boolean AS $$
BEGIN
  -- Allow prediction if:
  -- 1. Program airs today
  -- 2. Current time is before 22:00 on air date
  RETURN 
    DATE_TRUNC('day', program_air_date) = DATE_TRUNC('day', NOW()) AND
    EXTRACT(HOUR FROM NOW()) < 22;
END;
$$ LANGUAGE plpgsql;