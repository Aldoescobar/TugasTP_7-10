# TP7 — ERD dan Migration Domain Capstone
**NIM:** 253303610004 | **Nama:** Ronaldo Sianipar

## Domain: Equipment Booking System

Sistem peminjaman peralatan laboratorium kampus. Mahasiswa (member) dapat
meminjam equipment untuk rentang tanggal tertentu, dan admin mengelola
ketersediaan peralatan.

---

## 1. Entity-Relationship Diagram (ERD)

```
┌──────────────────┐         ┌──────────────────────┐         ┌──────────────────────┐
│      users       │         │      bookings        │         │     equipments       │
├──────────────────┤         ├──────────────────────┤         ├──────────────────────┤
│ PK id            │───1:N──▶│ PK id                │◀──N:1───│ PK id                │
│    name    (NN)  │         │ FK user_id      (NN) │         │    name        (NN)  │
│    email   (UQ)  │         │ FK equipment_id (NN) │         │    category    (NN)  │
│    role    (NN)  │         │    start_date   (NN) │         │    serial_number(UQ) │
│    created_at    │         │    end_date     (NN) │         │    status      (NN)  │
│    updated_at    │         │    status       (NN) │         │    daily_rate  (NN)  │
└──────────────────┘         │    total_cost   (NN) │         │    created_at        │
                             │    notes             │         │    updated_at        │
                             │    created_at        │         └──────────────────────┘
                             │    updated_at        │
                             └──────────────────────┘
```

### Kardinalitas
| Relasi | Tipe | Penjelasan |
|--------|------|------------|
| users → bookings | 1:N | Satu user bisa memiliki banyak booking |
| equipments → bookings | 1:N | Satu equipment bisa ada di banyak booking |
| bookings | Junction | Menghubungkan users dan equipments |

---

## 2. Primary Key, Foreign Key, dan Constraint

| Tabel | Kolom | Constraint |
|-------|-------|-----------|
| users | id | PRIMARY KEY (auto-increment) |
| users | email | NOT NULL, UNIQUE |
| users | name, role | NOT NULL |
| equipments | id | PRIMARY KEY (auto-increment) |
| equipments | serial_number | NOT NULL, UNIQUE |
| equipments | daily_rate | NOT NULL, CHECK (> 0) |
| bookings | id | PRIMARY KEY (auto-increment) |
| bookings | user_id | NOT NULL, FOREIGN KEY → users(id) |
| bookings | equipment_id | NOT NULL, FOREIGN KEY → equipments(id) |
| bookings | end_date, start_date | NOT NULL, CHECK (end_date > start_date) |
| bookings | total_cost | NOT NULL |

---

## 3. Index

| Tabel | Kolom/Komposit | Alasan |
|-------|---------------|--------|
| users | email (UNIQUE) | Pencarian login/autentikasi cepat |
| equipments | serial_number (UNIQUE) | Lookup peralatan berdasarkan nomor seri |
| equipments | status | Filter peralatan yang tersedia |
| bookings | equipment_id, start_date, end_date | **Query overlap** — mendeteksi apakah equipment sudah di-booking pada rentang tanggal tertentu. Index komposit ini sangat penting untuk performa karena digunakan setiap kali ada booking baru |
| bookings | user_id | Join/filter booking berdasarkan user |

---

## 4. Migration Rails

Lihat file: `db/migrate/20261109000001_create_tp7_domain_schema.rb`

Migration ini menggunakan satu file dengan `create_table` untuk ketiga tabel
dan `reversible` block untuk CHECK constraint agar mendukung rollback.

---

## 5. Operasi yang Memerlukan Transaction

**Pembuatan booking baru** wajib menggunakan database transaction karena:

1. **Atomicity**: Operasi melibatkan beberapa langkah — cek ketersediaan equipment
   (SELECT ... FOR UPDATE), hitung total_cost, dan INSERT ke bookings. Jika
   salah satu langkah gagal, semua harus di-rollback.

2. **Isolation**: Tanpa locking, dua request bersamaan bisa mengecek equipment
   yang sama sebagai "tersedia" dan menghasilkan double-booking (race condition).
   Penggunaan `Equipment.lock.find(id)` memastikan row-level lock selama transaction.

3. **Consistency**: Total cost dihitung berdasarkan `daily_rate` equipment saat itu.
   Jika rate berubah di tengah transaction, hasilnya harus konsisten dengan
   rate yang di-lock di awal.

```ruby
# Contoh implementasi:
ActiveRecord::Base.transaction do
  equipment = Equipment.lock.find(equipment_id)
  raise ConflictError if equipment.bookings.overlapping(start_date, end_date).exists?

  days = (end_date - start_date).to_i
  Booking.create!(
    user: current_user, equipment: equipment,
    start_date: start_date, end_date: end_date,
    status: "pending", total_cost: days * equipment.daily_rate
  )
end
```

Tanpa transaction, skenario kegagalan (misal: constraint violation pada CHECK
`end_date > start_date`) akan meninggalkan data dalam state tidak konsisten.
