# TP8 — Bukti Integritas Data Capstone
**NIM:** 253303610004 | **Nama:** Ronaldo Sianipar

## Domain: Equipment Booking System

---

## 1. ERD Final

```
┌──────────────┐       ┌────────────────┐       ┌──────────────────┐
│    users     │──1:N─▶│   bookings     │◀─N:1──│   equipments     │
├──────────────┤       ├────────────────┤       ├──────────────────┤
│ PK id        │       │ PK id          │       │ PK id            │
│ name    (NN) │       │ FK user_id(NN) │       │ name       (NN)  │
│ email   (UQ) │       │ FK equip_id(NN)│       │ category   (NN)  │
│ role    (NN) │       │ start_date(NN) │       │ serial_no  (UQ)  │
└──────────────┘       │ end_date  (NN) │       │ status     (NN)  │
                       │ status   (NN)  │       │ daily_rate (NN)  │
                       │ total_cost(NN) │       │   CHECK(> 0)     │
                       │ notes          │       └──────────────────┘
                       │ CHECK(end>start)│
                       └────────────────┘
```

---

## 2. Tabel Skenario Uji

| # | Skenario | Metode Pengujian | Hasil yang Diharapkan | Status |
|---|----------|------------------|-----------------------|--------|
| 1 | Migration dan rollback | `test "schema memiliki tabel..."` | Tabel users, equipments, bookings ada | ✅ |
| 2 | Association dua arah (user↔booking) | `test "user has_many bookings..."` | `user.bookings` mengandung booking, `booking.user` mengembalikan user | ✅ |
| 3 | Association dua arah (equipment↔booking) | `test "equipment has_many bookings..."` | `equipment.bookings` mengandung booking | ✅ |
| 4 | Validation: user tanpa email | `test "user tanpa email ditolak"` | Tidak valid, error "can't be blank" | ✅ |
| 5 | Validation: email duplikat | `test "user dengan email duplikat..."` | Tidak valid, error "has already been taken" | ✅ |
| 6 | Validation: daily_rate negatif | `test "equipment dengan daily_rate negatif..."` | Tidak valid, error "must be greater than 0" | ✅ |
| 7 | Validation: end_date < start_date | `test "booking dengan end_date sebelum..."` | Tidak valid, error "harus setelah start_date" | ✅ |
| 8 | UNIQUE constraint (DB level) email | `test "UNIQUE constraint pada users.email..."` | `ActiveRecord::RecordNotUnique` raised | ✅ |
| 9 | UNIQUE constraint (DB level) serial_number | `test "UNIQUE constraint pada equipments..."` | `ActiveRecord::RecordNotUnique` raised | ✅ |
| 10 | Foreign key constraint | `test "foreign key constraint..."` | `ActiveRecord::InvalidForeignKey` raised | ✅ |
| 11 | Transaction commit | `test "transaction commit..."` | Booking.count bertambah 1 | ✅ |
| 12 | Transaction rollback | `test "transaction rollback..."` | Booking.count tidak berubah | ✅ |
| 13 | Seed idempotent | `test "seed dapat dijalankan dua kali..."` | Hanya 1 record dengan email yang sama | ✅ |
| 14 | Overlap booking ditolak | `test "booking yang overlap..."` | Tidak valid, error overlap | ✅ |

---

## 3. File Test

Lokasi: `test/models/tp8_data_integrity_test.rb`

### Cara menjalankan:
```bash
bin/rails test test/models/tp8_data_integrity_test.rb
```

---

## 4. Evidence Constraint

### 4.1 NOT NULL
```ruby
user = User.new(name: nil, email: nil, role: nil)
user.valid? # => false
user.errors.full_messages
# => ["Name can't be blank", "Email can't be blank", ...]
```

### 4.2 UNIQUE (Database Level)
```ruby
User.create!(name: "A", email: "dup@test.com", role: "member")
User.new(name: "B", email: "dup@test.com", role: "member").save(validate: false)
# => ActiveRecord::RecordNotUnique (PG::UniqueViolation)
```

### 4.3 FOREIGN KEY
```ruby
Booking.new(user_id: 999999, equipment_id: 1, ...).save(validate: false)
# => ActiveRecord::InvalidForeignKey
```

### 4.4 CHECK Constraint
```sql
-- Di level database:
ALTER TABLE bookings ADD CONSTRAINT chk_bookings_end_after_start
  CHECK (end_date > start_date);

ALTER TABLE equipments ADD CONSTRAINT chk_equipments_daily_rate_positive
  CHECK (daily_rate > 0);
```

---

## 5. Seed Evidence

File: `db/seeds.rb`

Seed menggunakan `find_or_create_by!` sehingga idempotent — dapat dijalankan
berulang kali tanpa menghasilkan duplikasi data.

```bash
$ bin/rails db:seed
=== Seeding Equipment Booking System ===
  ✓ Users: 3 record(s)
  ✓ Equipments: 3 record(s)
  ✓ Bookings: 2 record(s)
=== Seeding selesai ===

$ bin/rails db:seed  # jalankan kedua kali
=== Seeding Equipment Booking System ===
  ✓ Users: 3 record(s)      # tetap 3, tidak duplikat
  ✓ Equipments: 3 record(s)
=== Seeding selesai ===
```
