# TP9 — Audit Separation of Concerns dan Error Contract
**NIM:** 253303610004 | **Nama:** Ronaldo Sianipar

## Endpoint yang Diaudit

**POST /api/v1/bookings** — Membuat booking baru untuk peminjaman equipment.

---

## 1. Diagram Alur

```
Client (Postman/Test)
    │
    │  POST /api/v1/bookings { booking: { ... } }
    ▼
┌─────────────────────────┐
│   Router (routes.rb)    │ ── Verb: POST, Path: /api/v1/bookings
│   → api/v1/bookings#    │    Controller: Api::V1::BookingsController
│     create              │    Action: create
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ BookingsController      │ ── HTTP concern only:
│ #create                 │    1. Extract strong params
│                         │    2. Delegate ke service
│                         │    3. Return response via serializer
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ Bookings::CreateService │ ── Business logic:
│ #call                   │    1. Find user & equipment
│                         │    2. Cek overlap (conflict)
│                         │    3. Hitung total_cost
│                         │    4. Create booking dalam transaction
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ Model: Booking          │ ── Data integrity:
│ (+ User, Equipment)     │    Validasi, association, callback
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ BookingSerializer       │ ── Formatting response:
│ #as_json / .error       │    Kontrak JSON yang konsisten
└────────────┬────────────┘
             ▼
        JSON Response
```

---

## 2. Tabel Audit: Sebelum vs Sesudah Refactor

### 2.1 Masalah yang Ditemukan (Sebelum Refactor)

| # | Lokasi | Masalah | Tanggung Jawab Seharusnya |
|---|--------|---------|---------------------------|
| 1 | `bookings_controller_before_refactor.rb` baris 20-25 | **Business logic di controller**: perhitungan `total_cost = days * daily_rate` dan pengecekan overlap dilakukan langsung di controller action | Seharusnya di **Service Object** (`Bookings::CreateService`) agar dapat di-reuse dan diuji secara terpisah |
| 2 | `bookings_controller_before_refactor.rb` baris 35-50 | **Serialisasi manual di controller**: response JSON dibangun dengan hash literal langsung di `render json: { id: ..., user_name: ... }` | Seharusnya di **Serializer** (`BookingSerializer`) agar format response konsisten di semua endpoint |

### 2.2 Perubahan yang Dilakukan

| Aspek | Sebelum (`BookingsControllerBeforeRefactor`) | Sesudah (`Api::V1::BookingsController`) |
|-------|----------------------------------------------|----------------------------------------|
| Perhitungan total_cost | Di controller (baris 22-23) | Di `Bookings::CreateService#build_booking` |
| Pengecekan overlap | Di controller (baris 26-31) | Di `Bookings::CreateService#overlapping?` |
| Format response | Hash literal manual di controller | `BookingSerializer#as_json` |
| Error handling | `rescue` di akhir method | Terpusat di `ApplicationController` + `handle_service_error` |
| Strong params | Tidak ada (langsung `params[:key]`) | `booking_params` dengan `require/permit` |

---

## 3. Error Contract

### 3.1 Respons Sukses — 201 Created

```json
{
  "data": {
    "id": 1,
    "type": "booking",
    "attributes": {
      "start_date": "2026-12-01",
      "end_date": "2026-12-03",
      "status": "pending",
      "total_cost": 300000.0,
      "notes": "Untuk presentasi",
      "created_at": "2026-11-09T13:00:00.000Z",
      "updated_at": "2026-11-09T13:00:00.000Z"
    },
    "relationships": {
      "user": { "id": 1, "name": "Budi Santoso" },
      "equipment": { "id": 1, "name": "Projector Epson EB-X51" }
    }
  }
}
```

### 3.2 Negative Case 1 — 422 Validation Failed

**Kondisi**: Field wajib hilang atau nilai tidak valid (misal `end_date < start_date`)

```json
{
  "error": {
    "status": 422,
    "type": "validation_failed",
    "messages": ["End date harus setelah start_date"]
  }
}
```

### 3.3 Negative Case 2 — 404 Not Found

**Kondisi**: `equipment_id` atau `user_id` tidak ditemukan di database

```json
{
  "error": {
    "status": 404,
    "type": "not_found",
    "messages": ["Couldn't find Equipment with 'id'=999999"]
  }
}
```

### 3.4 Negative Case 3 — 409 Conflict

**Kondisi**: Equipment sudah di-booking pada rentang tanggal yang diminta

```json
{
  "error": {
    "status": 409,
    "type": "conflict",
    "messages": ["Equipment sudah di-booking pada rentang tanggal tersebut"]
  }
}
```

---

## 4. Hasil Pengujian

Lihat file: `test/requests/api/v1/bookings_request_test.rb`

| # | Test Case | Expected Status | Result |
|---|-----------|----------------|--------|
| 1 | POST dengan data valid | 201 Created | ✅ PASS |
| 2 | POST tanpa user_id | 404 Not Found | ✅ PASS |
| 3 | POST tanpa parameter booking | 422 Unprocessable Entity | ✅ PASS |
| 4 | POST dengan equipment_id tidak valid | 404 Not Found | ✅ PASS |
| 5 | POST dengan tanggal overlap | 409 Conflict | ✅ PASS |
| 6 | POST dengan field tidak diizinkan (status=confirmed) | 201, status tetap "pending" | ✅ PASS |
| 7 | POST dengan end_date < start_date | 422 Unprocessable Entity | ✅ PASS |

---

## 5. Commit Hash

| Tahap | Commit Message | Hash |
|-------|---------------|------|
| Sebelum refactor | `feat(tp9): add controller before refactor with SoC violations` | `a6016e5` |
| Sesudah refactor | `refactor(tp9): extract service object and serializer, fix SoC` | `5bd0f8b` |

---

## 6. Refleksi (maks 150 kata)

Audit Separation of Concerns pada endpoint POST /api/v1/bookings mengungkap dua
pelanggaran utama: (1) business logic berupa perhitungan total_cost dan pengecekan
overlap yang bercampur di controller, dan (2) serialisasi response berupa hash
literal yang dibuat manual tanpa pola yang dapat diulang.

Refactor dilakukan dengan memindahkan seluruh business logic ke
`Bookings::CreateService` yang mengembalikan Result object, sementara formatting
response dipindahkan ke `BookingSerializer`. Controller kini hanya bertugas
menerima HTTP request, mendelegasikan ke service, dan mengembalikan response
terformat — sesuai prinsip thin controller.

Error contract dirancang konsisten: setiap error response memiliki struktur
`{ error: { status, type, messages } }` yang memudahkan klien frontend untuk
menangani semua kasus error secara seragam. Pengujian mencakup satu happy path
dan tiga negative case yang membuktikan kontrak berjalan sesuai spesifikasi.
