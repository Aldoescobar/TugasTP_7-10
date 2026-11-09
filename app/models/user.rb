# frozen_string_literal: true

class User < ApplicationRecord
  # ── Associations ──────────────────────────────────────────────
  has_many :bookings, dependent: :destroy

  # ── Validations ───────────────────────────────────────────────
  validates :name,  presence: true
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role,  presence: true,
                    inclusion: { in: %w[member admin] }

  # ── Scopes ────────────────────────────────────────────────────
  scope :admins,  -> { where(role: "admin") }
  scope :members, -> { where(role: "member") }
end
