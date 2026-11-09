# frozen_string_literal: true

# ApplicationController — Base controller untuk semua API controller
#
# Hanya menangani HTTP-level concerns:
#   - Format response default (JSON)
#   - Global error handling
#   - Strong parameters pattern

class ApplicationController < ActionController::API
  # ── Global Error Handling ───────────────────────────────────────
  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: BookingSerializer.error(404, "not_found", e.message),
           status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: BookingSerializer.error(422, "validation_failed", e.message),
           status: :unprocessable_entity
  end
end
