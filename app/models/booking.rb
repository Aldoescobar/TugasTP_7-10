# frozen_string_literal: true

class Booking < ApplicationRecord
  # ── Associations ──────────────────────────────────────────────
  belongs_to :user
  belongs_to :equipment

  # ── Validations ───────────────────────────────────────────────
  validates :start_date,  presence: true
  validates :end_date,    presence: true
  validates :status,      presence: true,
                          inclusion: { in: %w[pending confirmed cancelled] }
  validates :total_cost,  presence: true,
                          numericality: { greater_than_or_equal_to: 0 }

  validate :end_date_after_start_date, if: -> { start_date.present? && end_date.present? }
  validate :no_overlapping_booking,    if: -> { equipment_id.present? && start_date.present? && end_date.present? }

  # ── Scopes ────────────────────────────────────────────────────
  scope :active,   -> { where(status: %w[pending confirmed]) }
  scope :pending,  -> { where(status: "pending") }
  scope :confirmed, -> { where(status: "confirmed") }

  scope :overlapping, ->(start_d, end_d) {
    active.where("start_date < ? AND end_date > ?", end_d, start_d)
  }

  # ── Callbacks ─────────────────────────────────────────────────
  before_validation :calculate_total_cost, if: -> {
    total_cost.blank? && equipment.present? && start_date.present? && end_date.present?
  }

  private

  def end_date_after_start_date
    return if end_date > start_date

    errors.add(:end_date, "harus setelah start_date")
  end

  def no_overlapping_booking
    scope = equipment.bookings.overlapping(start_date, end_date)
    scope = scope.where.not(id: id) if persisted?

    return unless scope.exists?

    errors.add(:base, "Equipment sudah di-booking pada rentang tanggal tersebut")
  end

  def calculate_total_cost
    days = (end_date - start_date).to_i
    self.total_cost = days * equipment.daily_rate
  end
end
