/*
  # Fix prediction allowed function

  1. Changes
    - Update is_prediction_allowed function to use air_date directly
    - Allow predictions for programs airing today
    - Fix timezone handling

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing function
DROP FUNCTION IF EXISTS is_prediction_allowed(timestamptz);

-- Create updated function
CREATE OR REPLACE FUNCTION is_prediction_allowed(program_air_date timestamptz)
RETURNS boolean AS $$
BEGIN
  -- Allow prediction if program air date is in the future
  RETURN program_air_date > NOW();
END;
$$ LANGUAGE plpgsql;