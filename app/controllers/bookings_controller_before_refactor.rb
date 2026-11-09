# frozen_string_literal: true

# TP9 — BookingsControllerBeforeRefactor
#
# Controller INI SENGAJA ditulis dengan dua masalah SoC:
#
# Masalah 1 (baris 20-25): Business logic (perhitungan total_cost dan
#   pengecekan overlap) ada di dalam controller, bukan di service/model.
#
# Masalah 2 (baris 35-50): Serialisasi/formatting response dilakukan
#   manual di controller menggunakan hash literal, bukan melalui serializer.
#
# File ini dipertahankan sebagai bukti "sebelum refactor" untuk TP9.

class BookingsControllerBeforeRefactor < ApplicationController
  # POST /bookings (versi sebelum refactor)
  def create
    equipment = Equipment.find(params[:equipment_id])
    user      = User.find(params[:user_id])

    # ❌ Masalah 1: Business logic di controller
    # Seharusnya di service object atau model
    days       = (Date.parse(params[:end_date]) - Date.parse(params[:start_date])).to_i
    total_cost = days * equipment.daily_rate

    # Pengecekan overlap langsung di controller
    overlap = equipment.bookings
                       .where(status: %w[pending confirmed])
                       .where("start_date < ? AND end_date > ?",
                              params[:end_date], params[:start_date])
    if overlap.exists?
      render json: { error: "Equipment tidak tersedia" }, status: :conflict
      return
    end

    booking = Booking.new(
      user: user, equipment: equipment,
      start_date: params[:start_date], end_date: params[:end_date],
      status: "pending", total_cost: total_cost
    )

    if booking.save
      # ❌ Masalah 2: Serialisasi manual di controller
      # Seharusnya menggunakan BookingSerializer
      render json: {
        id:         booking.id,
        user_id:    booking.user_id,
        user_name:  booking.user.name,
        equipment:  booking.equipment.name,
        start_date: booking.start_date,
        end_date:   booking.end_date,
        status:     booking.status,
        total_cost: booking.total_cost.to_f,
        created_at: booking.created_at
      }, status: :created
    else
      render json: { errors: booking.errors.full_messages }, status: :unprocessable_entity
    end

  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end
end
