# Pemodelan Data Sistem Pelaporan Kerusakan Fasilitas Kampus

Isi repositori:
- `Laporan_Pemodelan_Data_Fasilitas_Kampus.docx`: laporan tahap konseptual, logis, dan fisik.
- `schema_pemodelan_fasilitas.sql`: skema MySQL, data dummy, trigger, dan contoh query.

## Cara menjalankan SQL
1. Buka phpMyAdmin atau MySQL Workbench.
2. Pilih menu SQL / buka file `schema_pemodelan_fasilitas.sql`.
3. Jalankan pada server MySQL 8.0.16 atau lebih baru.
4. Skrip membuat database baru bernama `pemodelan_fasilitas_kampus`.
5. Skrip menggunakan DROP TABLE untuk objek dalam database tersebut. Jangan jalankan pada database tugas lain yang berisi data penting.

## Catatan rancangan
- ERD konseptual berisi tujuh entitas utama: Gedung, Ruangan, Fasilitas, Pengguna, Teknisi, Laporan, dan Perbaikan.
- Email Pengguna yang dapat lebih dari satu dipisahkan menjadi tabel `pengguna_email` pada model logis.
- Perbaikan adalah entitas lemah dengan PK gabungan (`id_laporan`, `id_perbaikan`).
- Trigger memastikan tanggal mulai perbaikan tidak mendahului tanggal laporan dan membatasi satu perbaikan aktif per laporan.
- Data nama, email, nomor pengenal, dan fasilitas pada file adalah data dummy.
