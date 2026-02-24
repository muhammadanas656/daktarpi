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