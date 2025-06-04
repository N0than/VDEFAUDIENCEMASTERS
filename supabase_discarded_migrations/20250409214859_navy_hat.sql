/*
  # Fix notifications system and prevent infinite loops

  1. Changes
    - Add proper RLS policies for notifications
    - Fix notification triggers to prevent loops
    - Add proper error handling
    - Add indexes for performance

  2. Security
    - Enable RLS
    - Add proper validation
*/

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;

-- Create new policies
CREATE POLICY "notifications_select_policy"
ON notifications
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "notifications_update_policy"
ON notifications
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS on_program_created ON programs;
DROP TRIGGER IF EXISTS on_leaderboard_update ON leaderboard;
DROP TRIGGER IF EXISTS trigger_badge_notification ON leaderboard;
DROP FUNCTION IF EXISTS create_program_notification();
DROP FUNCTION IF EXISTS create_badge_notification();

-- Function to create program notification with error handling
CREATE OR REPLACE FUNCTION create_program_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert notification for all users
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message
  )
  SELECT 
    u.id as user_id,
    'program',
    'Nouveau programme disponible',
    'Le programme "' || NEW.name || '" est maintenant disponible pour vos pronostics !'
  FROM auth.users u
  WHERE EXISTS (
    SELECT 1 FROM user_roles ur
    WHERE ur.user_id = u.id
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't block the transaction
  RAISE WARNING 'Error creating program notification: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create badge notification with error handling
CREATE OR REPLACE FUNCTION create_badge_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create notification if score actually changed
  IF NEW.total_score = OLD.total_score AND 
     NEW.precision_score = OLD.precision_score AND
     NEW.rank = OLD.rank THEN
    RETURN NEW;
  END IF;

  -- Create notifications based on achievements
  IF NEW.total_score >= 1000 AND OLD.total_score < 1000 THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      NEW.user_id,
      'badge',
      'Badge débloqué !',
      'Félicitations ! Vous avez obtenu le badge "Expert TV" !'
    );
  END IF;

  -- Notification for 90%+ precision
  IF NEW.precision_score >= 90 AND OLD.precision_score < 90 THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      NEW.user_id,
      'badge',
      'Badge débloqué !',
      'Félicitations ! Vous avez obtenu le badge "Précision Extrême" !'
    );
  END IF;

  -- Notification for reaching top 3
  IF NEW.rank <= 3 AND OLD.rank > 3 THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message
    ) VALUES (
      NEW.user_id,
      'badge',
      'Badge débloqué !',
      'Félicitations ! Vous avez atteint le TOP 3 du classement !'
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't block the transaction
  RAISE WARNING 'Error creating badge notification: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers with proper conditions
CREATE TRIGGER on_program_created
  AFTER INSERT ON programs
  FOR EACH ROW
  EXECUTE FUNCTION create_program_notification();

CREATE TRIGGER trigger_badge_notification
  AFTER UPDATE OF total_score, precision_score, rank ON leaderboard
  FOR EACH ROW
  WHEN (
    NEW.total_score != OLD.total_score OR
    NEW.precision_score != OLD.precision_score OR
    NEW.rank != OLD.rank
  )
  EXECUTE FUNCTION create_badge_notification();

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';