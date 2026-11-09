# frozen_string_literal: true

# TP7/TP8 — Seed data untuk Equipment Booking System
#
# Jalankan: bin/rails db:seed
# Seed ini idempotent — aman dijalankan dua kali tanpa duplikasi
# karena menggunakan find_or_create_by pada field UNIQUE.

puts "=== Seeding Equipment Booking System ==="

# ── 1. Users ────────────────────────────────────────────────────
ActiveRecord::Base.transaction do
  admin = User.find_or_create_by!(email: "admin@kampus.ac.id") do |u|
    u.name = "Admin Lab"
    u.role = "admin"
  end

  member1 = User.find_or_create_by!(email: "budi@mahasiswa.ac.id") do |u|
    u.name = "Budi Santoso"
    u.role = "member"
  end

  member2 = User.find_or_create_by!(email: "siti@mahasiswa.ac.id") do |u|
    u.name = "Siti Rahayu"
    u.role = "member"
  end

  puts "  ✓ Users: #{User.count} record(s)"

  # ── 2. Equipments ──────────────────────────────────────────────
  projector = Equipment.find_or_create_by!(serial_number: "PRJ-001") do |e|
    e.name       = "Projector Epson EB-X51"
    e.category   = "Elektronik"
    e.status     = "available"
    e.daily_rate = 150_000
  end

  laptop = Equipment.find_or_create_by!(serial_number: "LPT-001") do |e|
    e.name       = "Laptop Lenovo ThinkPad"
    e.category   = "Komputer"
    e.status     = "available"
    e.daily_rate = 200_000
  end

  camera = Equipment.find_or_create_by!(serial_number: "CAM-001") do |e|
    e.name       = "Kamera Canon EOS M50"
    e.category   = "Fotografi"
    e.status     = "available"
    e.daily_rate = 250_000
  end

  puts "  ✓ Equipments: #{Equipment.count} record(s)"

  # ── 3. Bookings ────────────────────────────────────────────────
  unless Booking.exists?
    Booking.create!(
      user:       member1,
      equipment:  projector,
      start_date: Date.new(2026, 11, 10),
      end_date:   Date.new(2026, 11, 12),
      status:     "confirmed",
      total_cost: 2 * projector.daily_rate
    )

    Booking.create!(
      user:       member2,
      equipment:  laptop,
      start_date: Date.new(2026, 11, 11),
      end_date:   Date.new(2026, 11, 14),
      status:     "pending",
      total_cost: 3 * laptop.daily_rate
    )

    puts "  ✓ Bookings: #{Booking.count} record(s)"
  end
end

puts "=== Seeding selesai ==="
