# frozen_string_literal: true

# Api::V1::BookingsController — Controller SESUDAH refactor (TP9)
#
# Controller ini HANYA mengoordinasikan HTTP concerns:
#   1. Menerima request dan extract strong parameters
#   2. Mendelegasikan business logic ke Bookings::CreateService
#   3. Mengembalikan response melalui BookingSerializer
#
# Dibandingkan BookingsControllerBeforeRefactor:
#   ✅ Tidak ada business logic (perhitungan, pengecekan overlap)
#   ✅ Tidak ada serialisasi manual (menggunakan BookingSerializer)
#   ✅ Error handling terpusat di ApplicationController

module Api
  module V1
    class BookingsController < ApplicationController
      # GET /api/v1/bookings
      def index
        bookings = Booking.includes(:user, :equipment).order(created_at: :desc)
        render json: { data: bookings.map { |b| BookingSerializer.new(b).as_json[:data] } }
      end

      # GET /api/v1/bookings/:id
      def show
        booking = Booking.find(params[:id])
        render json: BookingSerializer.new(booking).as_json
      end

      # POST /api/v1/bookings
      #
      # Alur: route → controller → strong_params → CreateService
      #       → model/validation → serializer → response
      def create
        result = Bookings::CreateService.new(booking_params).call

        if result.success?
          render json: BookingSerializer.new(result.booking).as_json,
                 status: :created
        else
          handle_service_error(result)
        end
      end

      private

      # Strong parameters — hanya field yang diizinkan
      def booking_params
        params.require(:booking).permit(
          :user_id, :equipment_id, :start_date, :end_date, :notes
        )
      end

      def handle_service_error(result)
        case result.error_type
        when :not_found
          render json: BookingSerializer.error(404, "not_found", result.message),
                 status: :not_found
        when :conflict
          render json: BookingSerializer.error(409, "conflict", result.message),
                 status: :conflict
        when :validation_failed
          messages = result.booking&.errors&.full_messages || [result.message]
          render json: BookingSerializer.error(422, "validation_failed", messages),
                 status: :unprocessable_entity
        else
          render json: BookingSerializer.error(500, "internal_error", "Terjadi kesalahan"),
                 status: :internal_server_error
        end
      end
    end
  end
end
