-- =========================================================
-- SISTEM PELAPORAN KERUSAKAN FASILITAS KAMPUS
-- Skema fisik MySQL 8.0.16+
-- Jalankan pada database baru agar tidak bentrok dengan tabel lama.
-- =========================================================

CREATE DATABASE IF NOT EXISTS pemodelan_fasilitas_kampus
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pemodelan_fasilitas_kampus;

-- Untuk menjalankan ulang dari awal, hapus objek lama dalam urutan aman.
DROP TRIGGER IF EXISTS trg_perbaikan_bi;
DROP TRIGGER IF EXISTS trg_perbaikan_bu;
DROP TABLE IF EXISTS perbaikan;
DROP TABLE IF EXISTS laporan;
DROP TABLE IF EXISTS pengguna_email;
DROP TABLE IF EXISTS teknisi;
DROP TABLE IF EXISTS fasilitas;
DROP TABLE IF EXISTS pengguna;
DROP TABLE IF EXISTS ruangan;
DROP TABLE IF EXISTS gedung;

CREATE TABLE gedung (
    id_gedung INT AUTO_INCREMENT PRIMARY KEY,
    nama_gedung VARCHAR(100) NOT NULL UNIQUE,
    lokasi VARCHAR(150) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE ruangan (
    id_ruangan INT AUTO_INCREMENT PRIMARY KEY,
    id_gedung INT NOT NULL,
    nama_ruangan VARCHAR(100) NOT NULL,
    lantai INT NOT NULL,
    CONSTRAINT uq_ruangan_per_gedung UNIQUE (id_gedung, nama_ruangan),
    CONSTRAINT ck_ruangan_lantai CHECK (lantai >= 0),
    CONSTRAINT fk_ruangan_gedung FOREIGN KEY (id_gedung)
        REFERENCES gedung(id_gedung)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE fasilitas (
    id_fasilitas INT AUTO_INCREMENT PRIMARY KEY,
    id_ruangan INT NOT NULL,
    nama_fasilitas VARCHAR(120) NOT NULL,
    kode_qr VARCHAR(60) NOT NULL UNIQUE,
    CONSTRAINT fk_fasilitas_ruangan FOREIGN KEY (id_ruangan)
        REFERENCES ruangan(id_ruangan)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE pengguna (
    id_pengguna INT AUTO_INCREMENT PRIMARY KEY,
    nama_pengguna VARCHAR(120) NOT NULL,
    peran ENUM('Dosen','Mahasiswa','Tendik') NOT NULL,
    nomor_pengenal VARCHAR(40) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Email bersifat multivalued sehingga dipisahkan ke tabel tersendiri.
CREATE TABLE pengguna_email (
    id_pengguna INT NOT NULL,
    email VARCHAR(254) NOT NULL,
    PRIMARY KEY (id_pengguna, email),
    CONSTRAINT uq_email_global UNIQUE (email),
    CONSTRAINT fk_email_pengguna FOREIGN KEY (id_pengguna)
        REFERENCES pengguna(id_pengguna)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE teknisi (
    id_teknisi INT AUTO_INCREMENT PRIMARY KEY,
    nama_teknisi VARCHAR(120) NOT NULL,
    spesialis VARCHAR(120) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE laporan (
    id_laporan INT AUTO_INCREMENT PRIMARY KEY,
    id_pengguna INT NOT NULL,
    id_fasilitas INT NOT NULL,
    deskripsi_kerusakan TEXT NOT NULL,
    foto_bukti VARCHAR(255) NULL,
    tanggal_lapor DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tingkat_urgensi ENUM('Rendah','Sedang','Tinggi') NOT NULL DEFAULT 'Sedang',
    CONSTRAINT fk_laporan_pengguna FOREIGN KEY (id_pengguna)
        REFERENCES pengguna(id_pengguna)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_laporan_fasilitas FOREIGN KEY (id_fasilitas)
        REFERENCES fasilitas(id_fasilitas)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Perbaikan adalah entitas lemah; PK gabungan terdiri dari id_laporan
-- (FK ke laporan) dan id_perbaikan (partial key dalam satu laporan).
CREATE TABLE perbaikan (
    id_laporan INT NOT NULL,
    id_perbaikan INT NOT NULL,
    id_teknisi INT NOT NULL,
    tanggal_mulai DATETIME NOT NULL,
    tanggal_selesai DATETIME NULL,
    catatan_biaya DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    status_penanganan ENUM('Dijadwalkan','Diproses','Selesai','Dibatalkan')
        NOT NULL DEFAULT 'Dijadwalkan',
    PRIMARY KEY (id_laporan, id_perbaikan),
    CONSTRAINT ck_perbaikan_waktu CHECK (
        tanggal_selesai IS NULL OR tanggal_selesai >= tanggal_mulai
    ),
    CONSTRAINT ck_perbaikan_biaya CHECK (catatan_biaya >= 0),
    CONSTRAINT fk_perbaikan_laporan FOREIGN KEY (id_laporan)
        REFERENCES laporan(id_laporan)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_perbaikan_teknisi FOREIGN KEY (id_teknisi)
        REFERENCES teknisi(id_teknisi)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

DELIMITER //

CREATE TRIGGER trg_perbaikan_bi
BEFORE INSERT ON perbaikan
FOR EACH ROW
BEGIN
    DECLARE v_tanggal_lapor DATETIME;
    DECLARE v_jumlah_aktif INT DEFAULT 0;

    SELECT tanggal_lapor INTO v_tanggal_lapor
    FROM laporan
    WHERE id_laporan = NEW.id_laporan;

    IF NEW.tanggal_mulai < v_tanggal_lapor THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tanggal mulai perbaikan tidak boleh sebelum tanggal laporan';
    END IF;

    IF NEW.status_penanganan IN ('Dijadwalkan','Diproses') THEN
        SELECT COUNT(*) INTO v_jumlah_aktif
        FROM perbaikan
        WHERE id_laporan = NEW.id_laporan
          AND status_penanganan IN ('Dijadwalkan','Diproses');

        IF v_jumlah_aktif > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Satu laporan hanya boleh memiliki satu perbaikan aktif';
        END IF;
    END IF;
END//

CREATE TRIGGER trg_perbaikan_bu
BEFORE UPDATE ON perbaikan
FOR EACH ROW
BEGIN
    DECLARE v_tanggal_lapor DATETIME;
    DECLARE v_jumlah_aktif INT DEFAULT 0;

    SELECT tanggal_lapor INTO v_tanggal_lapor
    FROM laporan
    WHERE id_laporan = NEW.id_laporan;

    IF NEW.tanggal_mulai < v_tanggal_lapor THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tanggal mulai perbaikan tidak boleh sebelum tanggal laporan';
    END IF;

    IF NEW.status_penanganan IN ('Dijadwalkan','Diproses') THEN
        SELECT COUNT(*) INTO v_jumlah_aktif
        FROM perbaikan
        WHERE id_laporan = NEW.id_laporan
          AND NOT (id_laporan = OLD.id_laporan AND id_perbaikan = OLD.id_perbaikan)
          AND status_penanganan IN ('Dijadwalkan','Diproses');

        IF v_jumlah_aktif > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Satu laporan hanya boleh memiliki satu perbaikan aktif';
        END IF;
    END IF;
END//

DELIMITER ;

-- =========================================================
-- DATA CONTOH (DUMMY)
-- =========================================================
INSERT INTO gedung (id_gedung, nama_gedung, lokasi) VALUES
(1, 'Gedung A', 'Kampus Utara'),
(2, 'Gedung B', 'Kampus Selatan');

INSERT INTO ruangan (id_ruangan, id_gedung, nama_ruangan, lantai) VALUES
(1, 1, 'Lab Komputer 1', 1),
(2, 2, 'R-201', 2),
(3, 1, 'Toilet Lantai 1', 1);

INSERT INTO fasilitas (id_fasilitas, id_ruangan, nama_fasilitas, kode_qr) VALUES
(1, 1, 'AC Lab 1', 'QR-AC-001'),
(2, 2, 'Proyektor R-201', 'QR-PRJ-001'),
(3, 3, 'Keran Toilet', 'QR-KRN-001');

INSERT INTO pengguna (id_pengguna, nama_pengguna, peran, nomor_pengenal) VALUES
(1, 'Rina Wulandari', 'Dosen', '198501012010012001'),
(2, 'Andi Pratama', 'Mahasiswa', '264311099'),
(3, 'Siti Aminah', 'Tendik', '199001012015012002');

INSERT INTO pengguna_email (id_pengguna, email) VALUES
(1, 'rina@contoh.ac.id'),
(2, 'andi@contoh.ac.id'),
(3, 'siti@contoh.ac.id');

INSERT INTO teknisi (id_teknisi, nama_teknisi, spesialis) VALUES
(1, 'Budi Santoso', 'Listrik dan AC'),
(2, 'Dewi Lestari', 'Plumbing');

INSERT INTO laporan
(id_laporan, id_pengguna, id_fasilitas, deskripsi_kerusakan, foto_bukti, tanggal_lapor, tingkat_urgensi)
VALUES
(1, 2, 1, 'AC tidak dingin', 'foto/ac001.jpg', '2026-10-26 08:00:00', 'Tinggi'),
(2, 1, 2, 'Proyektor menampilkan gambar buram', NULL, '2026-10-26 09:30:00', 'Sedang'),
(3, 3, 3, 'Keran toilet bocor', 'foto/krn001.jpg', '2026-10-27 10:00:00', 'Rendah');

INSERT INTO perbaikan
(id_laporan, id_perbaikan, id_teknisi, tanggal_mulai, tanggal_selesai, catatan_biaya, status_penanganan)
VALUES
(1, 1, 1, '2026-10-26 13:00:00', '2026-10-26 15:00:00', 150000, 'Selesai'),
(2, 1, 1, '2026-10-27 08:00:00', NULL, 0, 'Diproses'),
(3, 1, 2, '2026-10-28 09:00:00', NULL, 0, 'Dijadwalkan');

-- =========================================================
-- CONTOH QUERY LAPORAN
-- =========================================================
SELECT
    l.id_laporan,
    p.nama_pengguna AS pelapor,
    f.nama_fasilitas,
    r.nama_ruangan,
    g.nama_gedung,
    l.deskripsi_kerusakan,
    l.tingkat_urgensi,
    COUNT(pb.id_perbaikan) AS jumlah_perbaikan
FROM laporan l
JOIN pengguna p ON p.id_pengguna = l.id_pengguna
JOIN fasilitas f ON f.id_fasilitas = l.id_fasilitas
JOIN ruangan r ON r.id_ruangan = f.id_ruangan
JOIN gedung g ON g.id_gedung = r.id_gedung
LEFT JOIN perbaikan pb ON pb.id_laporan = l.id_laporan
GROUP BY l.id_laporan, p.nama_pengguna, f.nama_fasilitas,
         r.nama_ruangan, g.nama_gedung, l.deskripsi_kerusakan,
         l.tingkat_urgensi
ORDER BY l.tanggal_lapor DESC;

-- =========================================================
-- CONTOH UJI CONSTRAINT (jalankan SATU PER SATU, hasil harus ditolak)
-- Jangan jalankan semua uji gagal dalam satu eksekusi.
-- =========================================================
-- 1. Biaya negatif -> ditolak oleh CHECK:
-- INSERT INTO perbaikan (id_laporan,id_perbaikan,id_teknisi,tanggal_mulai,catatan_biaya)
-- VALUES (1,2,1,'2026-10-28 10:00:00',-5000);

-- 2. Tanggal selesai sebelum tanggal mulai -> ditolak oleh CHECK:
-- INSERT INTO perbaikan (id_laporan,id_perbaikan,id_teknisi,tanggal_mulai,tanggal_selesai)
-- VALUES (1,2,1,'2026-10-28 10:00:00','2026-10-28 09:00:00');

-- 3. Perbaikan dimulai sebelum laporan dibuat -> ditolak oleh trigger:
-- INSERT INTO perbaikan (id_laporan,id_perbaikan,id_teknisi,tanggal_mulai)
-- VALUES (1,2,1,'2026-10-25 08:00:00');

-- 4. Laporan memakai pengguna yang tidak tersedia -> ditolak oleh FK:
-- INSERT INTO laporan (id_pengguna,id_fasilitas,deskripsi_kerusakan)
-- VALUES (99,1,'Uji foreign key');
