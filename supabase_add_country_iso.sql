-- Add country_iso to existing tables
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS country_iso text;
ALTER TABLE public.doctors ADD COLUMN IF NOT EXISTS country_iso text;
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS country_iso text;
