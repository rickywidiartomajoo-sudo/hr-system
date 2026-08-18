# HR System (Dragonworks Agency)

Sistem HRIS untuk pengajuan cuti (leave) dan reimburse karyawan, dengan role admin/hr/employee.

## Stack
- Frontend: HTML/JS statis (`index.html`) memakai Supabase JS client
- Backend: Supabase (Postgres + Auth + Storage)

## Setup
1. Buat project Supabase baru.
2. Jalankan `schema.sql` di SQL editor Supabase (membuat tabel, RLS, storage bucket).
3. Isi `SUPABASE_URL` dan `SUPABASE_ANON_KEY` di dalam `index.html`.
4. Deploy 5 Edge Functions berikut dengan `service_role` key (belum termasuk di repo ini,
   perlu dibuat ulang karena source aslinya tidak ada di frontend):
   - `create-user`
   - `update-user`
   - `delete-user`
   - `update-role`
   - `reset-password`
5. Hosting `index.html` bisa pakai static hosting apa saja (Netlify, Vercel, GitHub Pages, dll).

## File
- `index.html` — seluruh aplikasi frontend
- `schema.sql` — skema database + RLS policy + storage bucket
