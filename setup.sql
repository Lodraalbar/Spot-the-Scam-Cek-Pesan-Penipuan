-- SPOT THE SCAM - Supabase Setup SQL
-- Jalankan di Supabase SQL Editor

-- 1. Tabel users
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Tabel analysis_history
CREATE TABLE IF NOT EXISTS analysis_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  score INT NOT NULL,
  level TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'unreviewed',
  flags JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Tabel reports
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  phone TEXT,
  url TEXT,
  description TEXT,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2b. Kolom status untuk riwayat (jalankan juga bila tabel sudah ada)
ALTER TABLE analysis_history
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'unreviewed';

-- 4. RLS Policies (drop existing first)
DROP POLICY IF EXISTS "Users can view own data" ON users;
DROP POLICY IF EXISTS "Users can insert own data" ON users;
DROP POLICY IF EXISTS "Users can insert own history" ON analysis_history;
DROP POLICY IF EXISTS "Users can view own history" ON analysis_history;
DROP POLICY IF EXISTS "Users can update own history" ON analysis_history;
DROP POLICY IF EXISTS "Users can insert own reports" ON reports;
DROP POLICY IF EXISTS "Users can view own reports" ON reports;

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE analysis_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own data" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can insert own data" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own history" ON analysis_history
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own history" ON analysis_history
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own history" ON analysis_history
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can insert own reports" ON reports
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own reports" ON reports
  FOR SELECT USING (auth.uid() = user_id);

-- 4b. Daftar nomor terlapor lintas pengguna.
-- reports milik sendiri tidak bisa dibaca user lain, jadi nomornya disalin
-- ke tabel ini lewat trigger (SECURITY DEFINER) dan boleh dibaca siapa saja (termasuk pengunjung).
CREATE TABLE IF NOT EXISTS reported_numbers (
  phone TEXT PRIMARY KEY,
  report_count INT NOT NULL DEFAULT 1,
  last_report TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE reported_numbers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view reported numbers" ON reported_numbers;
-- Dibaca juga oleh pengunjung yang belum login, supaya status nomor tetap muncul
CREATE POLICY "Anyone can view reported numbers" ON reported_numbers
  FOR SELECT TO anon, authenticated USING (true);

CREATE OR REPLACE FUNCTION sync_reported_number() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF coalesce(NEW.phone, '') <> '' THEN
    INSERT INTO reported_numbers(phone) VALUES (NEW.phone)
    ON CONFLICT (phone) DO UPDATE
      SET report_count = reported_numbers.report_count + 1,
          last_report = now();
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_sync_reported_number ON reports;
CREATE TRIGGER trg_sync_reported_number AFTER INSERT ON reports
  FOR EACH ROW EXECUTE FUNCTION sync_reported_number();

-- Isi awal dari laporan lama (nomor lama tersimpan dipisah koma)
INSERT INTO reported_numbers(phone, report_count, last_report)
SELECT trim(n), count(*), max(r.created_at)
FROM reports r, regexp_split_to_table(coalesce(r.phone, ''), ',') AS n
WHERE trim(n) <> ''
GROUP BY trim(n)
ON CONFLICT (phone) DO NOTHING;

-- 5. Indexes
CREATE INDEX IF NOT EXISTS idx_history_user ON analysis_history(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_user ON reports(user_id);