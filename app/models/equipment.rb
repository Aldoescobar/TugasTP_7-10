# frozen_string_literal: true

class Equipment < ApplicationRecord
  # ── Associations ──────────────────────────────────────────────
  has_many :bookings, dependent: :destroy

  # ── Validations ───────────────────────────────────────────────
  validates :name,          presence: true
  validates :category,      presence: true
  validates :serial_number, presence: true, uniqueness: true
  validates :status,        presence: true,
                            inclusion: { in: %w[available maintenance retired] }
  validates :daily_rate,    presence: true,
                            numericality: { greater_than: 0 }

  # ── Scopes ────────────────────────────────────────────────────
  scope :available, -> { where(status: "available") }

  # ── Methods ───────────────────────────────────────────────────
  def available_for?(start_date, end_date)
    return false unless status == "available"

    !bookings.where(status: %w[pending confirmed])
             .where("start_date < ? AND end_date > ?", end_date, start_date)
             .exists?
  end
end
