# frozen_string_literal: true

# Bookings::CreateService — Service Object untuk membuat booking
#
# Tanggung jawab:
#   1. Validasi keberadaan user dan equipment
#   2. Pengecekan ketersediaan (overlap)
#   3. Perhitungan total_cost
#   4. Pembuatan record Booking dalam transaction
#
# Ini memindahkan business logic KELUAR dari controller
# sesuai prinsip Separation of Concerns (SoC).

module Bookings
  class CreateService
    Result = Struct.new(:success?, :booking, :error_type, :message, keyword_init: true)

    def initialize(params)
      @user_id      = params[:user_id]
      @equipment_id = params[:equipment_id]
      @start_date   = params[:start_date]
      @end_date     = params[:end_date]
      @notes        = params[:notes]
    end

    def call
      user      = find_user
      equipment = find_equipment

      return equipment_unavailable_result if overlapping?(equipment)

      booking = build_booking(user, equipment)

      ActiveRecord::Base.transaction do
        booking.save!
      end

      Result.new(success?: true, booking: booking)
    rescue ActiveRecord::RecordNotFound => e
      Result.new(success?: false, error_type: :not_found, message: e.message)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(
        success?: false, error_type: :validation_failed,
        booking: e.record, message: e.record.errors.full_messages.join(", ")
      )
    end

    private

    def find_user
      User.find(@user_id)
    end

    def find_equipment
      Equipment.find(@equipment_id)
    end

    def overlapping?(equipment)
      equipment.bookings.overlapping(
        Date.parse(@start_date.to_s),
        Date.parse(@end_date.to_s)
      ).exists?
    end

    def equipment_unavailable_result
      Result.new(
        success?: false,
        error_type: :conflict,
        message: "Equipment sudah di-booking pada rentang tanggal tersebut"
      )
    end

    def build_booking(user, equipment)
      days       = (Date.parse(@end_date.to_s) - Date.parse(@start_date.to_s)).to_i
      total_cost = days * equipment.daily_rate

      Booking.new(
        user:       user,
        equipment:  equipment,
        start_date: @start_date,
        end_date:   @end_date,
        status:     "pending",
        total_cost: total_cost,
        notes:      @notes
      )
    end
  end
end
