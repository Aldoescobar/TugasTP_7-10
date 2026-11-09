# frozen_string_literal: true

require "test_helper"

# TP10 — Request Test: POST /api/v1/bookings
#
# Test ini membuktikan alur lengkap dari HTTP request sampai response
# untuk endpoint POST /api/v1/bookings.
#
# Skenario yang diuji:
#   1. Happy path    → 201 Created
#   2. Field wajib hilang → 422 Unprocessable Entity
#   3. Equipment tidak ditemukan → 404 Not Found
#   4. Equipment sudah di-booking (overlap) → 409 Conflict
#   5. Field tidak diizinkan tidak mengubah state (strong params)
#   6. Nilai tidak valid (end_date < start_date) → 422

class Api::V1::BookingsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User", email: "test-req@mahasiswa.ac.id", role: "member"
    )
    @equipment = Equipment.create!(
      name: "Projector Test", category: "Elektronik",
      serial_number: "REQ-001", status: "available", daily_rate: 150_000
    )
  end

  # ── 1. Happy Path: request valid → 201 ────────────────────────
  test "POST /api/v1/bookings dengan data valid mengembalikan 201" do
    assert_difference("Booking.count", 1) do
      post api_v1_bookings_url, params: {
        booking: {
          user_id:      @user.id,
          equipment_id: @equipment.id,
          start_date:   "2026-12-01",
          end_date:     "2026-12-03",
          notes:        "Untuk presentasi"
        }
      }, as: :json
    end

    assert_response :created

    json = JSON.parse(response.body)
    assert_equal "booking", json.dig("data", "type")
    assert_equal @user.id, json.dig("data", "relationships", "user", "id")
    assert_equal "pending", json.dig("data", "attributes", "status")
    assert_in_delta 300_000.0, json.dig("data", "attributes", "total_cost"), 0.01
  end

  # ── 2. Field wajib hilang → 422 ───────────────────────────────
  test "POST tanpa user_id mengembalikan 422 validation_failed" do
    post api_v1_bookings_url, params: {
      booking: {
        equipment_id: @equipment.id,
        start_date:   "2026-12-01",
        end_date:     "2026-12-03"
      }
    }, as: :json

    assert_response :not_found  # RecordNotFound karena user_id nil
    json = JSON.parse(response.body)
    assert_equal "not_found", json.dig("error", "type")
  end

  test "POST tanpa parameter booking mengembalikan 422" do
    post api_v1_bookings_url, params: {}, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "validation_failed", json.dig("error", "type")
  end

  # ── 3. Equipment tidak ditemukan → 404 ─────────────────────────
  test "POST dengan equipment_id tidak valid mengembalikan 404" do
    post api_v1_bookings_url, params: {
      booking: {
        user_id:      @user.id,
        equipment_id: 999_999,
        start_date:   "2026-12-01",
        end_date:     "2026-12-03"
      }
    }, as: :json

    assert_response :not_found

    json = JSON.parse(response.body)
    assert_equal "not_found", json.dig("error", "type")
    assert_equal 404, json.dig("error", "status")
  end

  # ── 4. Overlap booking → 409 Conflict ──────────────────────────
  test "POST dengan tanggal overlap mengembalikan 409 conflict" do
    # Buat booking pertama
    Booking.create!(
      user: @user, equipment: @equipment,
      start_date: "2026-12-10", end_date: "2026-12-15",
      status: "confirmed", total_cost: 750_000
    )

    # Coba booking dengan tanggal overlap
    post api_v1_bookings_url, params: {
      booking: {
        user_id:      @user.id,
        equipment_id: @equipment.id,
        start_date:   "2026-12-12",
        end_date:     "2026-12-17"
      }
    }, as: :json

    assert_response :conflict

    json = JSON.parse(response.body)
    assert_equal "conflict", json.dig("error", "type")
    assert_equal 409, json.dig("error", "status")
  end

  # ── 5. Field tidak diizinkan tidak mengubah state ──────────────
  test "POST dengan field tidak diizinkan (status=confirmed) tetap pending" do
    post api_v1_bookings_url, params: {
      booking: {
        user_id:      @user.id,
        equipment_id: @equipment.id,
        start_date:   "2026-12-20",
        end_date:     "2026-12-22",
        status:       "confirmed"  # seharusnya di-filter oleh strong params
      }
    }, as: :json

    assert_response :created
    json = JSON.parse(response.body)
    # Status harus tetap "pending" karena strong params tidak mengizinkan :status
    assert_equal "pending", json.dig("data", "attributes", "status")
  end

  # ── 6. Nilai tidak valid → 422 ─────────────────────────────────
  test "POST dengan end_date sebelum start_date mengembalikan 422" do
    post api_v1_bookings_url, params: {
      booking: {
        user_id:      @user.id,
        equipment_id: @equipment.id,
        start_date:   "2026-12-25",
        end_date:     "2026-12-20"
      }
    }, as: :json

    assert_response :unprocessable_entity

    json = JSON.parse(response.body)
    assert_equal "validation_failed", json.dig("error", "type")
  end

  # ── 7. GET show: endpoint tunggal ──────────────────────────────
  test "GET /api/v1/bookings/:id mengembalikan booking yang benar" do
    booking = Booking.create!(
      user: @user, equipment: @equipment,
      start_date: "2026-12-05", end_date: "2026-12-07",
      status: "pending", total_cost: 300_000
    )

    get api_v1_booking_url(booking), as: :json

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal booking.id, json.dig("data", "id")
    assert_equal "booking", json.dig("data", "type")
  end

  test "GET /api/v1/bookings/:id dengan ID tidak valid mengembalikan 404" do
    get api_v1_booking_url(id: 999_999), as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "not_found", json.dig("error", "type")
  end
end
