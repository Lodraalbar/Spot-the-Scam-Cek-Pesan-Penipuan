-- Fix RLS untuk signup: allow anon insert ke users
DROP POLICY IF EXISTS "Allow anon insert for signup" ON users;

CREATE POLICY "Allow anon insert for signup" ON users
  FOR INSERT WITH CHECK (true);

-- Atau alternatif: disable RLS di users table saja (simpler untuk competition)
-- ALTER TABLE users DISABLE ROW LEVEL SECURITY;