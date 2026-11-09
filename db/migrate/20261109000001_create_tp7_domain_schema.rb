# frozen_string_literal: true

# TP7 — ERD dan Migration Domain Capstone
# Domain: Equipment Booking System
#
# Entitas:
#   1. users        — pengguna yang melakukan peminjaman
#   2. equipments   — peralatan yang dapat dipinjam
#   3. bookings     — transaksi peminjaman (junction table)
#
# Relasi:
#   users    1 ──< bookings >── 1 equipments
#   (satu user bisa punya banyak booking, satu equipment bisa ada di banyak booking)
#
# Constraint yang diterapkan:
#   - NOT NULL   : seluruh field wajib
#   - UNIQUE     : users.email, equipments.serial_number
#   - FOREIGN KEY: bookings.user_id → users.id, bookings.equipment_id → equipments.id
#   - CHECK      : bookings.end_date > bookings.start_date, equipments.daily_rate > 0
#   - INDEX      : bookings(user_id), bookings(equipment_id),
#                  bookings(equipment_id, start_date, end_date) untuk overlap query

class CreateTp7DomainSchema < ActiveRecord::Migration[7.1]
  def change
    # ── 1. Users ─────────────────────────────────────────────────
    create_table :users do |t|
      t.string  :name,  null: false
      t.string  :email, null: false
      t.string  :role,  null: false, default: "member" # member | admin

      t.timestamps
    end

    add_index :users, :email, unique: true

    # ── 2. Equipments ───────────────────────────────────────────
    create_table :equipments do |t|
      t.string  :name,          null: false
      t.string  :category,      null: false
      t.string  :serial_number, null: false
      t.string  :status,        null: false, default: "available" # available | maintenance | retired
      t.decimal :daily_rate,    null: false, precision: 10, scale: 2

      t.timestamps
    end

    add_index :equipments, :serial_number, unique: true
    add_index :equipments, :status

    # CHECK: daily_rate harus positif
    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE equipments
            ADD CONSTRAINT chk_equipments_daily_rate_positive
            CHECK (daily_rate > 0);
        SQL
      end
      dir.down do
        execute <<-SQL
          ALTER TABLE equipments
            DROP CONSTRAINT IF EXISTS chk_equipments_daily_rate_positive;
        SQL
      end
    end

    # ── 3. Bookings (junction table) ────────────────────────────
    create_table :bookings do |t|
      t.references :user,      null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true
      t.date       :start_date, null: false
      t.date       :end_date,   null: false
      t.string     :status,     null: false, default: "pending" # pending | confirmed | cancelled
      t.decimal    :total_cost, null: false, precision: 12, scale: 2
      t.text       :notes

      t.timestamps
    end

    # Index komposit untuk mencegah overlap booking pada equipment yang sama
    add_index :bookings, %i[equipment_id start_date end_date],
              name: "idx_bookings_equipment_date_range"

    # CHECK: end_date harus setelah start_date
    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE bookings
            ADD CONSTRAINT chk_bookings_end_after_start
            CHECK (end_date > start_date);
        SQL
      end
      dir.down do
        execute <<-SQL
          ALTER TABLE bookings
            DROP CONSTRAINT IF EXISTS chk_bookings_end_after_start;
        SQL
      end
    end
  end
end

# ── Operasi yang memerlukan transaction ─────────────────────────
#
# Pembuatan booking baru WAJIB di-wrap dalam transaction karena:
#
# 1. Harus mengecek ketersediaan equipment (SELECT ... FOR UPDATE)
#    untuk mencegah race condition double-booking.
# 2. Harus menghitung total_cost = daily_rate × jumlah hari,
#    lalu INSERT ke bookings.
# 3. Jika salah satu langkah gagal (misalnya equipment sudah di-book
#    oleh user lain), seluruh operasi harus di-rollback agar data
#    tetap konsisten.
#
# Contoh pseudocode:
#
#   ActiveRecord::Base.transaction do
#     equipment = Equipment.lock.find(equipment_id)
#     raise ConflictError if equipment.bookings.overlapping(start_date, end_date).exists?
#     Booking.create!(user: current_user, equipment: equipment, ...)
#   end
