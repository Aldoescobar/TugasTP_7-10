# frozen_string_literal: true

# BookingSerializer — Konsistensi format response JSON
#
# Memastikan setiap response Booking memiliki kontrak yang sama,
# terlepas dari controller mana yang memanggilnya.

class BookingSerializer
  def initialize(booking)
    @booking = booking
  end

  def as_json(_options = {})
    {
      data: {
        id:            @booking.id,
        type:          "booking",
        attributes:    attributes,
        relationships: relationships
      }
    }
  end

  # Format error response yang konsisten
  def self.error(status_code, error_type, messages)
    {
      error: {
        status:   status_code,
        type:     error_type,
        messages: Array(messages)
      }
    }
  end

  private

  def attributes
    {
      start_date: @booking.start_date,
      end_date:   @booking.end_date,
      status:     @booking.status,
      total_cost: @booking.total_cost.to_f,
      notes:      @booking.notes,
      created_at: @booking.created_at,
      updated_at: @booking.updated_at
    }
  end

  def relationships
    {
      user: {
        id:   @booking.user_id,
        name: @booking.user&.name
      },
      equipment: {
        id:   @booking.equipment_id,
        name: @booking.equipment&.name
      }
    }
  end
end
