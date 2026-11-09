# Spot the Scam

Cek pesan, tautan, nomor HP, atau screenshot yang mencurigakan sebelum Anda membalas atau membayar. Dibuat untuk MIT-WEEK 2026, tema *Guardians of the Digital Space*.

## Fitur

- **Analisis teks** — tempel isi pesan, lalu dapatkan level risiko (AMAN / MENCURIGAKAN / BAHAYA), skor 0–100, dan daftar temuan.
- **Analisis gambar** — tarik atau pilih screenshot chat; teks dibaca otomatis lewat OCR lalu langsung dianalisis.
- **Pencocokan daftar hitam** — nomor HP pelaku dicocokkan dengan daftar laporan yang tersimpan.
- **Deteksi tautan** — domain resmi vs tautan pendek/tidak dikenal (`bit.ly`, `tinyurl`, dan sejenisnya).
- **Riwayat analisis** — setiap pemeriksaan tersimpan ke Supabase dan bisa dibuka lagi dari menu akun.
- **Laporkan** — hasil berisiko bisa dilaporkan; laporan masuk ke tabel `reports` dengan status `pending`.
- **Akun** — daftar dan masuk dengan Supabase Auth. Halaman utama hanya bisa dibuka setelah login.

## Tech stack

| Bagian | Teknologi |
| --- | --- |
| Antarmuka | HTML, CSS, JavaScript vanilla (tanpa framework) |
| OCR | [Tesseract.js](https://tesseract.projectnaptha.com/) (`ind+eng`, jalan di browser) |
| Auth & database | [Supabase](https://supabase.com/) (`supabase-js` v2) |
| Hosting | Static hosting (GitHub Pages / Vercel / Netlify) |

## Struktur

```
.
├── index.html          # pengalih ke halaman login
├── setup.sql           # skema tabel + policy RLS
├── lomba/
│   ├── login.html      # daftar & masuk
│   ├── home.html       # analisis teks/gambar, riwayat, laporan
│   └── logo.png
└── TODO.txt
```

## Menjalankan lokal

Tidak ada proses build. Jalankan server statis dari root repo:

```bash
python -m http.server 8000
```

Lalu buka <http://localhost:8000/lomba/login.html>.

Membuka `home.html` langsung lewat `file://` juga bisa, tetapi server lokal lebih dekat dengan kondisi produksi (CDN, worker OCR, dan penyimpanan sesi).

## Database

1. Buat project Supabase.
2. Jalankan `setup.sql` di SQL Editor.
3. Isi `SUPABASE_URL` dan `SUPABASE_ANON_KEY` di `lomba/login.html` dan `lomba/home.html` (keduanya harus sama).
4. Matikan **Authentication → Sign In / Providers → Email → Confirm email** agar pendaftaran langsung bisa dipakai tanpa verifikasi email.

Tabel:

- `users` — cermin data akun (`id` mengikuti `auth.users.id`).
- `analysis_history` — `user_id`, `message`, `score`, `level`, `flags`, `created_at`.
- `reports` — `user_id`, `phone`, `url`, `description`, `status`.

## Cara kerja skor

Setiap pola berbahaya menambah bobot: file `.apk` (+100, langsung BAHAYA), permintaan transfer/DP (+40/+30), OTP/PIN (+40), iming-iming hadiah (+30), tautan pendek (+30), urgensi waktu (+20), nomor rekening pribadi (+30), tautan non-domain resmi (+20). Nomor yang ada di daftar hitam menambah +100. Skor ≥ 80 atau ada pola berbahaya = **BAHAYA**; skor 1–79 = **MENCURIGAKAN**; 0 = **AMAN**.

## Catatan

- Kunci `anon` memang dipakai di sisi klien dan aman selama RLS aktif; jangan pernah menaruh `service_role` key di file ini.
- Deteksi berbasis teks hasil OCR dan aturan pola — bukan analisis visual, jadi gambar buram perlu diketik ulang.
- Laporan penipuan dimoderasi manual lewat Supabase Table Editor.
