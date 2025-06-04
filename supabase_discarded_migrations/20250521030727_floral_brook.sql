/*
  # Update prediction rules to allow same-day predictions

  1. Changes
    - Remove time restriction from prediction validation
    - Allow predictions on the same day as program air date
    - Keep validation for past programs

  2. Security
    - Maintain existing RLS policies
*/

-- Drop existing function
DROP FUNCTION IF EXISTS is_prediction_allowed(timestamptz);

-- Create updated function without time restriction
CREATE OR REPLACE FUNCTION is_prediction_allowed(program_air_date timestamptz)
RETURNS boolean AS $$
BEGIN
  -- Allow prediction if:
  -- 1. Program airs today or in the future
  -- 2. No time restriction on the day of airing
  RETURN DATE_TRUNC('day', program_air_date) >= DATE_TRUNC('day', NOW());
END;
$$ LANGUAGE plpgsql;