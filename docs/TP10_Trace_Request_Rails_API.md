# TP10 — Trace Satu Request Rails API
**NIM:** 253303610004 | **Nama:** Ronaldo Sianipar

## Endpoint yang Di-trace

**POST /api/v1/bookings** — Membuat booking baru untuk peminjaman equipment.

---

## 1. Routes

```
Verb  URI Pattern                     Controller#Action
GET   /api/v1/bookings(.:format)      api/v1/bookings#index
POST  /api/v1/bookings(.:format)      api/v1/bookings#create
GET   /api/v1/bookings/:id(.:format)  api/v1/bookings#show
```

File: `config/routes.rb`

---

## 2. Diagram Trace

```
┌─────────────┐    POST /api/v1/bookings
│   Client    │────────────────────────────────┐
│ (Postman/   │    Content-Type: application/  │
│  Test)      │    json                        │
└─────────────┘                                ▼
                                    ┌──────────────────┐
                                    │  Rails Router     │
                                    │  config/routes.rb │
                                    │                   │
                                    │  Match: POST      │
                                    │  → api/v1/        │
                                    │    bookings#create│
                                    └────────┬─────────┘
                                             ▼
                                    ┌──────────────────┐
                                    │ ApplicationCtrl   │
                                    │ rescue_from       │
                                    │  RecordNotFound   │
                                    │  ParameterMissing │
                                    └────────┬─────────┘
                                             ▼
                                    ┌──────────────────┐
                                    │ BookingsCtrl      │
                                    │ #create           │
                                    │                   │
                                    │ 1. booking_params │
                                    │    (strong params)│
                                    │ 2. CreateService  │
                                    │    .new.call      │
                                    │ 3. handle result  │
                                    └────────┬─────────┘
                                             ▼
                                    ┌──────────────────┐
                                    │ Bookings::        │
                                    │ CreateService     │
                                    │                   │
                                    │ 1. find_user      │
                                    │ 2. find_equipment │
                                    │ 3. overlapping?   │
                                    │ 4. build_booking  │
                                    │ 5. transaction    │
                                    │    save!          │
                                    └────────┬─────────┘
                                             ▼
                                    ┌──────────────────┐
                                    │ Model: Booking    │
                                    │ (+ User, Equip)  │
                                    │                   │
                                    │ validates ...     │
                                    │ before_validation │
                                    │  calculate_cost   │
                                    └────────┬─────────┘
                                             ▼
                                    ┌──────────────────┐
                                    │ BookingSerializer │
                                    │ #as_json          │
                                    │                   │
                                    │ → { data: {      │
                                    │     id, type,    │
                                    │     attributes,  │
                                    │     relations    │
                                    │   }}             │
                                    └────────┬─────────┘
                                             ▼
                                    ┌──────────────────┐
                                    │  JSON Response   │
                                    │  Status: 201     │
                                    └──────────────────┘
```

---

## 3. Tabel Trace per Tahap

| # | Tahap | Input | Keputusan/Proses | Output | Lokasi File |
|---|-------|-------|------------------|--------|-------------|
| 1 | **Router** | `POST /api/v1/bookings` + JSON body | Match route → namespace api/v1, resource bookings, action create | Dispatch ke `Api::V1::BookingsController#create` | `config/routes.rb` |
| 2 | **Strong Parameters** | `params[:booking]` hash | `require(:booking).permit(:user_id, :equipment_id, :start_date, :end_date, :notes)` — filter field tidak diizinkan (misal `:status`) | Hash yang sudah di-sanitize | `app/controllers/api/v1/bookings_controller.rb#booking_params` |
| 3 | **Controller** | Sanitized params | Instantiate `Bookings::CreateService.new(params).call`, kemudian cek `result.success?` | Result object (success/error) | `app/controllers/api/v1/bookings_controller.rb#create` |
| 4 | **Service** | params hash | 1. `User.find(user_id)` 2. `Equipment.find(equipment_id)` 3. Cek overlap 4. Hitung total_cost 5. `Booking.new(...).save!` dalam transaction | `Result(success?: true, booking:)` atau `Result(success?: false, error_type:, message:)` | `app/services/bookings/create_service.rb` |
| 5 | **Model** | Booking attributes | Jalankan validasi: presence, inclusion, custom (end_date > start_date, no overlap). Callback: `calculate_total_cost` | Valid record atau `ActiveRecord::RecordInvalid` | `app/models/booking.rb` |
| 6 | **Serializer** | Booking object | Map ke JSON structure: `{ data: { id, type, attributes, relationships } }` | Formatted JSON hash | `app/serializers/booking_serializer.rb` |
| 7 | **Response** | JSON hash + status code | `render json: ..., status: :created` | HTTP 201 + JSON body | `app/controllers/api/v1/bookings_controller.rb#create` |

---

## 4. Skenario Uji

### 4.1 Happy Path — 201 Created

**Request:**
```bash
curl -X POST http://localhost:3000/api/v1/bookings \
  -H "Content-Type: application/json" \
  -d '{
    "booking": {
      "user_id": 1,
      "equipment_id": 1,
      "start_date": "2026-12-01",
      "end_date": "2026-12-03",
      "notes": "Untuk presentasi"
    }
  }'
```

**Response (201):**
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

### 4.2 Negative Case 1 — 422 Validation Failed

**Request:** POST dengan `end_date` sebelum `start_date`
```bash
curl -X POST http://localhost:3000/api/v1/bookings \
  -H "Content-Type: application/json" \
  -d '{
    "booking": {
      "user_id": 1,
      "equipment_id": 1,
      "start_date": "2026-12-25",
      "end_date": "2026-12-20"
    }
  }'
```

**Response (422):**
```json
{
  "error": {
    "status": 422,
    "type": "validation_failed",
    "messages": ["End date harus setelah start_date"]
  }
}
```

### 4.3 Negative Case 2 — 404 Not Found

**Request:** POST dengan `equipment_id` yang tidak ada
```bash
curl -X POST http://localhost:3000/api/v1/bookings \
  -H "Content-Type: application/json" \
  -d '{
    "booking": {
      "user_id": 1,
      "equipment_id": 999999,
      "start_date": "2026-12-01",
      "end_date": "2026-12-03"
    }
  }'
```

**Response (404):**
```json
{
  "error": {
    "status": 404,
    "type": "not_found",
    "messages": ["Couldn't find Equipment with 'id'=999999"]
  }
}
```

### 4.4 Negative Case 3 — 409 Conflict (Overlap)

**Request:** POST dengan tanggal yang overlap dengan booking existing
```bash
curl -X POST http://localhost:3000/api/v1/bookings \
  -H "Content-Type: application/json" \
  -d '{
    "booking": {
      "user_id": 1,
      "equipment_id": 1,
      "start_date": "2026-12-02",
      "end_date": "2026-12-05"
    }
  }'
```

**Response (409):**
```json
{
  "error": {
    "status": 409,
    "type": "conflict",
    "messages": ["Equipment sudah di-booking pada rentang tanggal tersebut"]
  }
}
```

### 4.5 Field Tidak Diizinkan (Strong Params)

**Request:** POST dengan `status: "confirmed"` (tidak diizinkan)
```bash
curl -X POST http://localhost:3000/api/v1/bookings \
  -H "Content-Type: application/json" \
  -d '{
    "booking": {
      "user_id": 1,
      "equipment_id": 1,
      "start_date": "2026-12-20",
      "end_date": "2026-12-22",
      "status": "confirmed"
    }
  }'
```

**Response (201):** Status tetap `"pending"` — field `status` di-filter oleh strong params.

---

## 5. Masalah yang Ditemukan

| Aspek | Detail |
|-------|--------|
| **Masalah** | Controller sebelum refactor memiliki business logic (perhitungan cost, overlap check) dan serialisasi manual yang bercampur — melanggar SoC |
| **Root Cause** | Tidak ada service layer dan serializer; semua logic ditulis langsung di controller action |
| **Perbaikan** | 1. Buat `Bookings::CreateService` untuk business logic 2. Buat `BookingSerializer` untuk format response 3. Controller hanya mengoordinasikan HTTP flow |
| **Commit** | Sebelum: `a6016e5`, Sesudah: `5bd0f8b`, Docs+Test: `c7f7e38` |

---

## 6. File yang Terlibat

| File | Peran |
|------|-------|
| `config/routes.rb` | Routing: map verb+path → controller#action |
| `app/controllers/application_controller.rb` | Base controller, global error handling |
| `app/controllers/api/v1/bookings_controller.rb` | HTTP coordination, strong params |
| `app/services/bookings/create_service.rb` | Business logic, transaction |
| `app/models/booking.rb` | Validasi, association, callback |
| `app/models/user.rb` | Validasi user |
| `app/models/equipment.rb` | Validasi equipment, availability check |
| `app/serializers/booking_serializer.rb` | JSON formatting |
| `test/requests/api/v1/bookings_request_test.rb` | Integration/request test |
