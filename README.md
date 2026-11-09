# Equipment Booking System — Rails API (TP7–TP10)
**NIM:** 253303610004 | **Nama:** Ronaldo Sianipar

Proyek Rails API untuk sistem peminjaman peralatan laboratorium kampus.
Dibuat sebagai evidence portfolio untuk tugas TP7 sampai TP10.

## Domain

Sistem peminjaman peralatan (**Equipment Booking System**) yang memungkinkan
mahasiswa (`member`) meminjam peralatan lab untuk rentang tanggal tertentu,
dengan admin yang mengelola ketersediaan.

### Entitas

| Entitas | Deskripsi |
|---------|-----------|
| **User** | Pengguna sistem (role: `member` / `admin`) |
| **Equipment** | Peralatan yang dapat dipinjam (projector, laptop, kamera, dsb.) |
| **Booking** | Transaksi peminjaman yang menghubungkan user dan equipment |

### ERD Singkat

```
users 1──< bookings >──1 equipments
```

---

## Struktur Proyek

```
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── bookings_controller_before_refactor.rb   ← TP9 (sebelum)
│   │   └── api/v1/
│   │       └── bookings_controller.rb               ← TP9 (sesudah)
│   ├── models/
│   │   ├── application_record.rb
│   │   ├── user.rb
│   │   ├── equipment.rb
│   │   └── booking.rb
│   ├── serializers/
│   │   └── booking_serializer.rb
│   └── services/
│       └── bookings/
│           └── create_service.rb
├── config/
│   └── routes.rb
├── db/
│   ├── migrate/
│   │   └── 20261109000001_create_tp7_domain_schema.rb
│   └── seeds.rb
├── test/
│   ├── models/
│   │   └── tp8_data_integrity_test.rb
│   └── requests/
│       └── api/v1/
│           └── bookings_request_test.rb
├── docs/
│   ├── TP7_ERD_dan_Migration.md
│   ├── TP8_Bukti_Integritas_Data.md
│   ├── TP9_Audit_SoC_dan_Error_Contract.md
│   └── TP10_Trace_Request_Rails_API.md
└── README.md
```

---

## Tugas per TP

### TP7 — ERD dan Migration Domain Capstone
- ERD dengan 3 entitas (users, equipments, bookings)
- Migration Rails dengan NOT NULL, UNIQUE, FOREIGN KEY, CHECK, INDEX
- Penjelasan transaction untuk pembuatan booking
- 📄 Laporan: `docs/TP7_ERD_dan_Migration.md`

### TP8 — Bukti Integritas Data
- 14 test case untuk membuktikan integritas data
- Mencakup: migration, association, validation, constraint DB, transaction, seed
- 📄 Laporan: `docs/TP8_Bukti_Integritas_Data.md`
- 🧪 Test: `test/models/tp8_data_integrity_test.rb`

### TP9 — Audit SoC dan Error Contract
- Audit controller sebelum refactor (2 masalah SoC)
- Refactor: extract `Bookings::CreateService` dan `BookingSerializer`
- Error contract: 201, 422, 404, 409
- 📄 Laporan: `docs/TP9_Audit_SoC_dan_Error_Contract.md`

### TP10 — Trace Request Rails API
- Trace POST /api/v1/bookings dari route sampai response
- Tabel setiap tahap: input, proses, output, lokasi file
- Happy path + 3 negative case + strong params test
- 📄 Laporan: `docs/TP10_Trace_Request_Rails_API.md`
- 🧪 Test: `test/requests/api/v1/bookings_request_test.rb`

---

## Cara Menjalankan

```bash
# Setup database
bin/rails db:create db:migrate db:seed

# Jalankan semua test
bin/rails test

# Jalankan test spesifik
bin/rails test test/models/tp8_data_integrity_test.rb
bin/rails test test/requests/api/v1/bookings_request_test.rb

# Lihat routes
bin/rails routes --grep bookings

# Start server
bin/rails server
```

---

## Git Log

```
git log --oneline
c7f7e38 docs(tp10): add trace request documentation and request tests
5bd0f8b refactor(tp9): extract service object and serializer, fix SoC
a6016e5 feat(tp9): add controller before refactor with SoC violations
3086698 test(tp8): add data integrity tests for domain schema
6f54757 feat(data): add tp7 domain schema, models, and seeds
```

---

## Catatan

- Proyek ini menggunakan **Rails API mode** (`ActionController::API`)
- Database: **PostgreSQL** (disarankan, karena menggunakan CHECK constraint)
- Tidak menyertakan: password, token, secret, log mentah, atau data pribadi
