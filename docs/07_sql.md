-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.appointments (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  doctor_id bigint NOT NULL,
  clinic_id bigint NOT NULL,
  schedule_date date NOT NULL,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  status text DEFAULT 'confirmed'::text CHECK (status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'completed'::text, 'canceled'::text])),
  created_at timestamp with time zone DEFAULT now(),
  patient_name text,
  patient_gender text,
  patient_dob date,
  patient_phone text,
  patient_email text,
  patient_image_url text,
  reminder_minutes integer DEFAULT 0,
  idempotency_key uuid UNIQUE,
  deleted_at timestamp with time zone,
  CONSTRAINT appointments_pkey PRIMARY KEY (id),
  CONSTRAINT appointments_doctor_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id),
  CONSTRAINT appointments_clinic_fkey FOREIGN KEY (clinic_id) REFERENCES public.clinics(id),
  CONSTRAINT appointments_user_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.banners (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  title text,
  subtitle text,
  image_url text,
  is_active boolean DEFAULT true,
  CONSTRAINT banners_pkey PRIMARY KEY (id)
);
CREATE TABLE public.clinics (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  name text NOT NULL,
  address text,
  latitude double precision,
  longitude double precision,
  created_at timestamp with time zone DEFAULT now(),
  type text DEFAULT 'clinic'::text,
  image_url text,
  CONSTRAINT clinics_pkey PRIMARY KEY (id)
);
CREATE TABLE public.doctor_clinics (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  doctor_id bigint,
  clinic_id bigint,
  visit_price numeric,
  created_at timestamp with time zone DEFAULT now(),
  avg_wait_time text DEFAULT '20-30 mins'::text,
  CONSTRAINT doctor_clinics_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_clinics_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id),
  CONSTRAINT doctor_clinics_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES public.clinics(id)
);
CREATE TABLE public.doctor_schedules (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  doctor_id bigint,
  clinic_id bigint,
  day_of_week text NOT NULL,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  slot_duration_minutes integer DEFAULT 30,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT doctor_schedules_pkey PRIMARY KEY (id),
  CONSTRAINT doctor_schedules_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id),
  CONSTRAINT doctor_schedules_clinic_id_fkey FOREIGN KEY (clinic_id) REFERENCES public.clinics(id)
);
CREATE TABLE public.doctors (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  full_name text NOT NULL,
  specialty_id bigint,
  profile_picture_url text,
  rating numeric,
  hourly_rate numeric,
  description text,
  is_popular boolean DEFAULT false,
  is_featured boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  reviews_count integer DEFAULT 0,
  location text DEFAULT 'Unknown'::text,
  experience_years integer DEFAULT 0,
  patients_served integer DEFAULT 0,
  views_count integer DEFAULT 0,
  CONSTRAINT doctors_pkey PRIMARY KEY (id),
  CONSTRAINT doctors_specialty_id_fkey FOREIGN KEY (specialty_id) REFERENCES public.specialties(id)
);
CREATE TABLE public.favorite_doctors (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  doctor_id bigint NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT favorite_doctors_pkey PRIMARY KEY (id),
  CONSTRAINT favorite_doctors_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.doctors(id),
  CONSTRAINT favorite_doctors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.medical_records (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  record_for text NOT NULL,
  record_type text NOT NULL,
  record_date date NOT NULL,
  file_urls ARRAY DEFAULT '{}'::text[],
  created_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT medical_records_pkey PRIMARY KEY (id),
  CONSTRAINT medical_records_user_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  full_name text,
  phone_number text,
  date_of_birth date,
  location text,
  profile_picture_url text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.recovery_codes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  code_hash text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  used boolean DEFAULT false,
  CONSTRAINT recovery_codes_pkey PRIMARY KEY (id),
  CONSTRAINT recovery_codes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.spatial_ref_sys (
  srid integer NOT NULL CHECK (srid > 0 AND srid <= 998999),
  auth_name character varying,
  auth_srid integer,
  srtext character varying,
  proj4text character varying,
  CONSTRAINT spatial_ref_sys_pkey PRIMARY KEY (srid)
);
CREATE TABLE public.specialties (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  name text NOT NULL,
  icon_url text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT specialties_pkey PRIMARY KEY (id)
);
CREATE TABLE public.trusted_devices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  device_hash text NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  biometric_public_key text,
  is_biometric_enabled boolean DEFAULT false,
  CONSTRAINT trusted_devices_pkey PRIMARY KEY (id),
  CONSTRAINT trusted_devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);








Here are the final, production-ready SQL scripts for your database. You can save these in your version control or database migration files for future use.

These scripts include all the architectural upgrades we finalized: the 10-doctor default cluster, the `app_settings` dynamic limits, the `LEAST()` ceiling fix, and the dynamic sorting router.

### 1. Settings Table & Dynamic Radius Calculator
Run this block to ensure your settings table exists, and then create the `get_smart_cluster_radius` function.

```sql
-- Create the settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.app_settings (
  key TEXT PRIMARY KEY,
  value NUMERIC NOT NULL,
  description TEXT
);



INSERT INTO public.app_settings (key, value, description) VALUES 
('max_search_radius_km', 500.0, 'Global maximum search radius (Slider ceiling)'),
('min_search_radius_km', 25.0, 'Global minimum ground limit (Slider floor)'),
('featured_search_radius_km', 30.0, 'Rigid monetization radius for the Featured section')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 2. Upgrade the Smart Cluster Calculator
CREATE OR REPLACE FUNCTION get_smart_cluster_radius(
  p_user_lat DOUBLE PRECISION,
  p_user_lng DOUBLE PRECISION,
  p_user_country TEXT,
  p_target_cluster_size INT DEFAULT 10
) RETURNS DOUBLE PRECISION AS $$
DECLARE
  v_calculated_radius DOUBLE PRECISION;
  v_dynamic_max DOUBLE PRECISION;
  v_dynamic_min DOUBLE PRECISION;
BEGIN
  -- Hydrate limits directly from the settings table
  SELECT value INTO v_dynamic_max FROM app_settings WHERE key = 'max_search_radius_km';
  IF v_dynamic_max IS NULL THEN v_dynamic_max := 500.0; END IF;

  SELECT value INTO v_dynamic_min FROM app_settings WHERE key = 'min_search_radius_km';
  IF v_dynamic_min IS NULL THEN v_dynamic_min := 25.0; END IF;

  -- Calculate the raw cluster distance
  SELECT calc_distance INTO v_calculated_radius
  FROM (
    SELECT dc.doctor_id,
           MIN(6371 * acos(LEAST(1.0, GREATEST(-1.0, 
              cos(radians(p_user_lat)) * cos(radians(c.latitude)) * cos(radians(c.longitude) - radians(p_user_lng)) + 
              sin(radians(p_user_lat)) * sin(radians(c.latitude))
           )))) AS calc_distance
    FROM doctor_clinics dc
    JOIN clinics c ON c.id = dc.clinic_id
    JOIN doctors d ON d.id = dc.doctor_id
    WHERE c.latitude IS NOT NULL AND c.longitude IS NOT NULL
      AND d.country_iso = p_user_country
    GROUP BY dc.doctor_id
    ORDER BY calc_distance ASC
    LIMIT p_target_cluster_size
  ) subquery
  ORDER BY calc_distance DESC
  LIMIT 1;

  IF v_calculated_radius IS NULL THEN
    RETURN -1.0; 
  END IF;

  -- The Ultimate Clamp: Forces the radius to respect your database rules
  RETURN GREATEST(v_dynamic_min, LEAST(v_calculated_radius, v_dynamic_max));
END;
$$ LANGUAGE plpgsql;

---

### 2. The Master Production Fetcher
This is your centralized query engine that powers the Search, Featured, Popular, and Specialty screens via its dynamic `ORDER BY` routing.

```sql
-- -----------------------------------------------------------------------------
-- FUNCTION 2: The Master Production Fetcher
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_production_doctors(
  p_search_query TEXT DEFAULT NULL,
  p_filter_type TEXT DEFAULT 'All',       
  p_category TEXT DEFAULT NULL,           
  p_user_country TEXT DEFAULT NULL,
  p_user_location TEXT DEFAULT NULL,
  p_user_lat DOUBLE PRECISION DEFAULT NULL,
  p_user_lng DOUBLE PRECISION DEFAULT NULL,
  p_max_radius_km DOUBLE PRECISION DEFAULT NULL,
  p_local_day TEXT DEFAULT NULL,          
  p_local_time TIME DEFAULT NULL,         
  p_specialty_id BIGINT DEFAULT NULL,     
  p_clinic_id BIGINT DEFAULT NULL,        
  p_limit INT DEFAULT 20,                 
  p_offset INT DEFAULT 0                  
) RETURNS SETOF doctors AS $$
BEGIN
  RETURN QUERY
  
  WITH ValidDoctors AS (
    SELECT 
      d.id AS doc_id,
      
      -- Calculate spatial distance if requested
      CASE WHEN (p_filter_type IN ('Nearest', 'Available Today') OR p_max_radius_km IS NOT NULL) AND p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL THEN
        (SELECT MIN(6371 * acos(LEAST(1.0, GREATEST(-1.0, 
            cos(radians(p_user_lat)) * cos(radians(c.latitude)) * cos(radians(c.longitude) - radians(p_user_lng)) + 
            sin(radians(p_user_lat)) * sin(radians(c.latitude))
         ))))
         FROM doctor_clinics dc JOIN clinics c ON c.id = dc.clinic_id 
         WHERE dc.doctor_id = d.id AND c.latitude IS NOT NULL AND c.longitude IS NOT NULL)
      ELSE NULL END AS calc_distance,
      
      -- Check facility type (Hospital vs Clinic)
      CASE WHEN p_filter_type IN ('Hospital', 'Clinic') THEN
        EXISTS (SELECT 1 FROM doctor_clinics dc JOIN clinics c ON c.id = dc.clinic_id WHERE dc.doctor_id = d.id AND c.type = lower(p_filter_type))
      ELSE TRUE END AS matches_facility,
      
      -- Check schedule availability
      CASE WHEN p_filter_type = 'Available Today' AND p_local_day IS NOT NULL AND p_local_time IS NOT NULL THEN
        EXISTS (SELECT 1 FROM doctor_schedules ds WHERE ds.doctor_id = d.id AND lower(trim(ds.day_of_week)) = lower(trim(p_local_day)) AND ds.end_time > p_local_time)
      ELSE TRUE END AS matches_schedule

    FROM doctors d
    WHERE 
      (CASE 
        WHEN p_user_country IS NOT NULL THEN d.country_iso = p_user_country
        WHEN p_user_location IS NOT NULL THEN d.location = p_user_location
        ELSE TRUE 
      END)
      
      -- Category Filtering (Popular is math-driven, Featured is boolean-driven)
      AND (
        p_category IS NULL 
        OR p_category = 'Popular' 
        OR (p_category = 'Featured' AND d.is_featured = TRUE)
      )
           
      -- Global Search matching (Name, Specialty, or Clinic Name)
      AND (
        p_search_query IS NULL OR trim(p_search_query) = '' 
        OR d.full_name ILIKE '%' || trim(p_search_query) || '%'
        OR EXISTS (
          SELECT 1 FROM specialties s 
          WHERE s.id = d.specialty_id AND s.name ILIKE '%' || trim(p_search_query) || '%'
        )
        OR EXISTS (
          SELECT 1 FROM doctor_clinics dc JOIN clinics c ON c.id = dc.clinic_id 
          WHERE dc.doctor_id = d.id AND c.name ILIKE '%' || trim(p_search_query) || '%'
        )
      )
      
      AND (p_specialty_id IS NULL OR d.specialty_id = p_specialty_id)
      AND (p_clinic_id IS NULL OR EXISTS (
        SELECT 1 FROM doctor_clinics dc WHERE dc.doctor_id = d.id AND dc.clinic_id = p_clinic_id
      ))
  )
  
  -- Final Select & Join
  SELECT d.* FROM doctors d
  JOIN ValidDoctors vd ON d.id = vd.doc_id
  WHERE vd.matches_facility = TRUE 
    AND vd.matches_schedule = TRUE
    AND (p_max_radius_km IS NULL OR vd.calc_distance <= p_max_radius_km)
    
  -- The Dynamic Sorting Router
  ORDER BY 
    -- ROUTE A: "Featured" -> Localized Fair-Share Randomizer
    CASE WHEN p_category = 'Featured' THEN RANDOM() ELSE 1.0 END ASC,
    
    -- ROUTE B: "Popular" -> The Weighted Quality Matrix (Rating * Log(Reviews))
    CASE WHEN p_category = 'Popular' THEN (COALESCE(d.rating, 0.0) * LOG(COALESCE(d.reviews_count, 0) + 2.0)) ELSE NULL END DESC NULLS LAST,
    CASE WHEN p_category = 'Popular' THEN COALESCE(d.patients_served, 0) ELSE NULL END DESC NULLS LAST,
    
    -- ROUTE C: User tapped "Top Rated"
    CASE WHEN p_filter_type IN ('Best Rated', 'Top Rated') THEN d.rating ELSE NULL END DESC NULLS LAST,
    
    -- ROUTE D: The Universal Fallback -> Closest distance, then most views
    vd.calc_distance ASC NULLS LAST,
    d.views_count DESC NULLS LAST
  
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;
```