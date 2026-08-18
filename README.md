# HR System (Dragonworks Agency)

Sistem HRIS untuk pengajuan cuti (leave) dan reimburse karyawan, dengan role admin/hr/employee.

## Stack
- Frontend: HTML/JS statis (`index.html`) memakai Supabase JS client
- Backend: Supabase (Postgres + Auth + Storage)

## Setup
1. Buat project Supabase baru.
2. Jalankan `schema.sql` di SQL editor Supabase (membuat tabel, RLS, storage bucket).
3. Isi `SUPABASE_URL` dan `SUPABASE_ANON_KEY` di dalam `index.html`.
4. Deploy 5 Edge Functions di `supabase/functions/` (source-nya sudah ada di repo ini,
   sudah live juga di project Supabase saat ini):
   - `create-user` — buat karyawan baru (auth user + row profiles)
   - `update-user` — update data karyawan
   - `delete-user` — hapus karyawan (admin only)
   - `update-role` — ubah role karyawan (admin only)
   - `reset-password` — reset password karyawan (admin/hr)

   Semuanya jalan pakai `service_role` key (auto tersedia di env Edge Function),
   dan mengecek role pemanggil dari tabel `profiles` sebelum mengizinkan aksi.
   Untuk redeploy manual pakai Supabase CLI:
   ```
   supabase functions deploy create-user
   supabase functions deploy update-user
   supabase functions deploy delete-user
   supabase functions deploy update-role
   supabase functions deploy reset-password
   ```
5. Hosting `index.html` bisa pakai static hosting apa saja (Netlify, Vercel, GitHub Pages, dll).

## File
- `index.html` — seluruh aplikasi frontend
- `schema.sql` — skema database + RLS policy + storage bucket
