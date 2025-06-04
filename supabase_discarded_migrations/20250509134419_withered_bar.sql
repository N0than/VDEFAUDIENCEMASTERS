/*
  # Fix prediction scoring and ranking views

  1. Changes
    - Drop dependent views in correct order
    - Create predictions_with_accuracy2 view with new scoring
    - Recreate ranking views with proper GROUP BY clauses
    - Update existing predictions

  2. Security
    - Maintain existing RLS policies
*/

-- Drop dependent views in correct order
DROP VIEW IF EXISTS public.monthly_user_rankings_previous;
DROP VIEW IF EXISTS public.weekly_user_rankings_previous;
DROP VIEW IF EXISTS public.classement_general;
DROP VIEW IF EXISTS public.classement_par_genre;
DROP VIEW IF EXISTS public.classement_par_chaine;
DROP VIEW IF EXISTS public.classement_par_programme;
DROP VIEW IF EXISTS public.semestre_user_rankings;
DROP VIEW IF EXISTS public.weekly_user_rankings;
DROP VIEW IF EXISTS public.classement_semaine_en_cours;
DROP VIEW IF EXISTS public.classement_mois_en_cours;
DROP VIEW IF EXISTS public.classement_semaine;
DROP VIEW IF EXISTS public.predictions_with_accuracy2;

-- Create improved view with new scoring calculation
CREATE VIEW public.predictions_with_accuracy2 AS
SELECT 
  p.id AS prediction_id,
  p.user_id AS user_id,
  p.program_id AS program_id,
  p.predicted_audience AS predicted_audience,
  pr.real_audience AS real_audience,
  
  -- Accuracy calculation
  CASE
    WHEN p.predicted_audience <= pr.real_audience THEN ROUND((p.predicted_audience / pr.real_audience) * 100, 2)
    ELSE ROUND((pr.real_audience / p.predicted_audience) * 100, 2)
  END AS calculated_accuracy,

  -- Score calculation with sports bonus
  ROUND(
    (
      CASE
        WHEN (
          CASE
            WHEN p.predicted_audience <= pr.real_audience THEN ROUND((p.predicted_audience / pr.real_audience) * 100, 2)
            ELSE ROUND((pr.real_audience / p.predicted_audience) * 100, 2)
          END
        ) >= 95 THEN 100
        WHEN (
          CASE
            WHEN p.predicted_audience <= pr.real_audience THEN ROUND((p.predicted_audience / pr.real_audience) * 100, 2)
            ELSE ROUND((pr.real_audience / p.predicted_audience) * 100, 2)
          END
        ) >= 90 THEN 80
        WHEN (
          CASE
            WHEN p.predicted_audience <= pr.real_audience THEN ROUND((p.predicted_audience / pr.real_audience) * 100, 2)
            ELSE ROUND((pr.real_audience / p.predicted_audience) * 100, 2)
          END
        ) >= 85 THEN 60
        WHEN (
          CASE
            WHEN p.predicted_audience <= pr.real_audience THEN ROUND((p.predicted_audience / pr.real_audience) * 100, 2)
            ELSE ROUND((pr.real_audience / p.predicted_audience) * 100, 2)
          END
        ) >= 80 THEN 50
        WHEN (
          CASE
            WHEN p.predicted_audience <= pr.real_audience THEN ROUND((p.predicted_audience / pr.real_audience) * 100, 2)
            ELSE ROUND((pr.real_audience / p.predicted_audience) * 100, 2)
          END
        ) >= 70 THEN 30
        WHEN (
          CASE
            WHEN p.predicted_audience <= pr.real_audience THEN ROUND((p.predicted_audience / pr.real_audience) * 100, 2)
            ELSE ROUND((pr.real_audience / p.predicted_audience) * 100, 2)
          END
        ) >= 60 THEN 20
        WHEN (
          CASE
            WHEN p.predicted_audience <= pr.real_audience THEN ROUND((p.predicted_audience / pr.real_audience) * 100, 2)
            ELSE ROUND((pr.real_audience / p.predicted_audience) * 100, 2)
          END
        ) >= 50 THEN 10
        ELSE 0
      END
      *
      CASE
        WHEN pr.genre = 'Sport'
          AND pr.real_score_team1 IS NOT NULL
          AND pr.real_score_team2 IS NOT NULL
          AND p.predicted_score_team1 = pr.real_score_team1
          AND p.predicted_score_team2 = pr.real_score_team2
        THEN 2
        WHEN pr.genre = 'Sport'
          AND pr.real_score_team1 IS NOT NULL
          AND pr.real_score_team2 IS NOT NULL
          AND (
            (pr.real_score_team1 > pr.real_score_team2 AND p.predicted_score_team1 > p.predicted_score_team2) OR
            (pr.real_score_team1 < pr.real_score_team2 AND p.predicted_score_team1 < p.predicted_score_team2) OR
            (pr.real_score_team1 = pr.real_score_team2 AND p.predicted_score_team1 = p.predicted_score_team2)
          )
        THEN 1.5
        ELSE 1
      END
    ), 0
  )::INTEGER AS calculated_score,

  p.created_at AS created_at,
  pr.genre AS genre,
  p.predicted_score_team1,
  p.predicted_score_team2,
  pr.real_score_team1,
  pr.real_score_team2

FROM predictions p
JOIN programs pr ON p.program_id = pr.id;

-- Recreate weekly rankings view
CREATE VIEW public.weekly_user_rankings AS
WITH weekly_data AS (
  SELECT 
    p.user_id,
    date_trunc('week', p.created_at) as week,
    SUM(p.calculated_score) as total_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as precision_score,
    COUNT(*) as predictions_count,
    MAX(p.created_at) as latest_prediction
  FROM predictions_with_accuracy2 p
  WHERE p.created_at >= date_trunc('week', CURRENT_DATE)
  GROUP BY p.user_id, date_trunc('week', p.created_at)
)
SELECT 
  gen_random_uuid() as id,
  wd.user_id,
  wd.week,
  wd.total_score,
  wd.precision_score,
  ROW_NUMBER() OVER (
    ORDER BY wd.total_score DESC, 
            wd.precision_score DESC,
            wd.latest_prediction ASC
  ) as rank,
  NOW() as updated_at,
  pr.username,
  pr.avatar_url,
  wd.predictions_count
FROM weekly_data wd
JOIN profiles pr ON wd.user_id = pr.id;

-- Recreate monthly rankings view
CREATE VIEW public.classement_mois_en_cours AS
WITH monthly_data AS (
  SELECT 
    p.user_id,
    date_trunc('month', p.created_at) as month,
    SUM(p.calculated_score) as total_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as precision_score,
    COUNT(*) as predictions_count,
    MAX(p.created_at) as latest_prediction
  FROM predictions_with_accuracy2 p
  WHERE p.created_at >= date_trunc('month', CURRENT_DATE)
  GROUP BY p.user_id, date_trunc('month', p.created_at)
)
SELECT 
  gen_random_uuid() as id,
  md.user_id,
  md.month,
  md.total_score,
  md.precision_score,
  ROW_NUMBER() OVER (
    ORDER BY md.total_score DESC, 
            md.precision_score DESC,
            md.latest_prediction ASC
  ) as rank,
  NOW() as updated_at,
  pr.username,
  pr.avatar_url,
  md.predictions_count
FROM monthly_data md
JOIN profiles pr ON md.user_id = pr.id;

-- Recreate semester rankings view
CREATE VIEW public.semestre_user_rankings AS
WITH semester_data AS (
  SELECT 
    p.user_id,
    SUM(p.calculated_score) as total_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as precision_score,
    COUNT(*) as predictions_count,
    MAX(p.created_at) as latest_prediction
  FROM predictions_with_accuracy2 p
  WHERE p.created_at >= date_trunc('month', CURRENT_DATE - INTERVAL '6 months')
  GROUP BY p.user_id
)
SELECT 
  gen_random_uuid() as id,
  sd.user_id,
  sd.total_score,
  sd.precision_score,
  ROW_NUMBER() OVER (
    ORDER BY sd.total_score DESC, 
            sd.precision_score DESC,
            sd.latest_prediction ASC
  ) as rank,
  NOW() as updated_at,
  pr.username,
  pr.avatar_url,
  sd.predictions_count
FROM semester_data sd
JOIN profiles pr ON sd.user_id = pr.id;

-- Recreate program rankings view
CREATE VIEW public.classement_par_programme AS
SELECT 
  gen_random_uuid() as id,
  p.user_id,
  p.program_id,
  p.calculated_score as total_score,
  p.calculated_accuracy as precision_score,
  ROW_NUMBER() OVER (
    PARTITION BY p.program_id
    ORDER BY p.calculated_score DESC,
            p.calculated_accuracy DESC,
            p.created_at ASC
  ) as rank,
  p.created_at as updated_at,
  pr.username,
  pr.avatar_url,
  1 as predictions_count
FROM predictions_with_accuracy2 p
JOIN profiles pr ON p.user_id = pr.id;

-- Recreate genre rankings view
CREATE VIEW public.classement_par_genre AS
WITH genre_data AS (
  SELECT 
    p.user_id,
    p.genre,
    SUM(p.calculated_score) as total_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as precision_score,
    COUNT(*) as predictions_count,
    MAX(p.created_at) as latest_prediction
  FROM predictions_with_accuracy2 p
  GROUP BY p.user_id, p.genre
)
SELECT 
  gen_random_uuid() as id,
  gd.user_id,
  gd.genre,
  gd.total_score,
  gd.precision_score,
  ROW_NUMBER() OVER (
    PARTITION BY gd.genre
    ORDER BY gd.total_score DESC,
            gd.precision_score DESC,
            gd.latest_prediction ASC
  ) as rank,
  gd.latest_prediction as updated_at,
  pr.username,
  pr.avatar_url,
  gd.predictions_count
FROM genre_data gd
JOIN profiles pr ON gd.user_id = pr.id;

-- Recreate channel rankings view
CREATE VIEW public.classement_par_chaine AS
WITH channel_data AS (
  SELECT 
    p.user_id,
    pg.channel,
    SUM(p.calculated_score) as total_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as precision_score,
    COUNT(*) as predictions_count,
    MAX(p.created_at) as latest_prediction
  FROM predictions_with_accuracy2 p
  JOIN programs pg ON p.program_id = pg.id
  GROUP BY p.user_id, pg.channel
)
SELECT 
  gen_random_uuid() as id,
  cd.user_id,
  cd.channel,
  cd.total_score,
  cd.precision_score,
  ROW_NUMBER() OVER (
    PARTITION BY cd.channel
    ORDER BY cd.total_score DESC,
            cd.precision_score DESC,
            cd.latest_prediction ASC
  ) as rank,
  cd.latest_prediction as updated_at,
  pr.username,
  pr.avatar_url,
  cd.predictions_count
FROM channel_data cd
JOIN profiles pr ON cd.user_id = pr.id;

-- Recreate general rankings view
CREATE VIEW public.classement_general AS
WITH general_data AS (
  SELECT 
    p.user_id,
    SUM(p.calculated_score) as total_score,
    ROUND(AVG(p.calculated_accuracy)::numeric, 1) as precision_score,
    COUNT(*) as predictions_count,
    MAX(p.created_at) as latest_prediction
  FROM predictions_with_accuracy2 p
  GROUP BY p.user_id
)
SELECT 
  gen_random_uuid() as id,
  gd.user_id,
  gd.total_score,
  gd.precision_score,
  gd.predictions_count,
  ROW_NUMBER() OVER (
    ORDER BY gd.total_score DESC,
            gd.precision_score DESC,
            gd.latest_prediction ASC
  ) as current_rank,
  cgs.previous_rank,
  CASE 
    WHEN cgs.previous_rank IS NULL THEN 'new'
    WHEN ROW_NUMBER() OVER (ORDER BY gd.total_score DESC) < cgs.previous_rank THEN 'up'
    WHEN ROW_NUMBER() OVER (ORDER BY gd.total_score DESC) > cgs.previous_rank THEN 'down'
    ELSE NULL
  END as trend,
  COALESCE(
    cgs.previous_rank - ROW_NUMBER() OVER (ORDER BY gd.total_score DESC),
    0
  ) as rank_change,
  gd.latest_prediction as updated_at,
  pr.username,
  pr.avatar_url,
  ROW_NUMBER() OVER (
    ORDER BY gd.total_score DESC,
            gd.precision_score DESC,
            gd.latest_prediction ASC
  ) as rank
FROM general_data gd
JOIN profiles pr ON gd.user_id = pr.id
LEFT JOIN classement_general_snapshot cgs ON gd.user_id = cgs.user_id;

-- Recreate weekly rankings history view
CREATE VIEW public.weekly_user_rankings_previous AS
SELECT 
  user_id,
  week,
  previous_rank,
  total_score,
  precision_score,
  predictions_count,
  updated_at
FROM weekly_user_rankings;

-- Recreate monthly rankings history view
CREATE VIEW public.monthly_user_rankings_previous AS
SELECT 
  user_id,
  month,
  previous_rank,
  total_score,
  precision_score,
  predictions_count,
  updated_at
FROM classement_mois_en_cours;

-- Update existing predictions with new calculation
WITH updated_predictions AS (
  SELECT 
    p.id,
    pwa.calculated_accuracy,
    pwa.calculated_score
  FROM predictions p
  JOIN predictions_with_accuracy2 pwa ON p.id = pwa.prediction_id
)
UPDATE predictions p
SET
  calculated_accuracy = up.calculated_accuracy,
  calculated_score = up.calculated_score
FROM updated_predictions up
WHERE p.id = up.id;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';