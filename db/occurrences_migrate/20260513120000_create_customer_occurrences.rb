# frozen_string_literal: true

class CreateCustomerOccurrences < ActiveRecord::Migration[8.2]
  def change
    create_table(:customer_occurrence_statuses) do |t|
      t.string(:name, default: "", null: false)
    end

    reversible do |dir|
      dir.up { seed_customer_occurrence_statuses }
    end

    create_table(:customer_occurrences) do |t|
      t.string(:body, default: "", null: false)
      t.jsonb(:context, default: {}, null: false)
      t.string(:event_type, default: "", null: false)
      t.datetime(:lapses_at, default: -> { "'infinity'" }, null: false)
      t.string(:memo, default: "", null: false)
      t.string(:public_id, limit: 21, default: "", null: false)
      t.datetime(:purge_at, default: -> { "'infinity'" }, null: false)
      t.bigint(:status_id, default: 0, null: false)
      t.timestamps

      t.index(:body, unique: true)
      t.index(%i[event_type created_at])
      t.index(:public_id, unique: true)
      t.index(:purge_at)
      t.index(%i[status_id created_at])
    end

    create_table(:area_customer_occurrences) do |t|
      t.bigint(:area_occurrence_id, null: false)
      t.bigint(:customer_occurrence_id, null: false)
      t.timestamps

      t.index(
        %i[area_occurrence_id customer_occurrence_id],
        name: "idx_area_customer_occ_on_ids",
        unique: true,
      )
      t.index(:customer_occurrence_id)
    end

    create_table(:email_customer_occurrences) do |t|
      t.bigint(:email_occurrence_id, null: false)
      t.bigint(:customer_occurrence_id, null: false)
      t.timestamps

      t.index(
        %i[email_occurrence_id customer_occurrence_id],
        name: "idx_email_customer_occ_on_ids",
        unique: true,
      )
      t.index(:customer_occurrence_id)
    end

    create_table(:ip_customer_occurrences) do |t|
      t.bigint(:ip_occurrence_id, null: false)
      t.bigint(:customer_occurrence_id, null: false)
      t.timestamps

      t.index(
        %i[ip_occurrence_id customer_occurrence_id],
        name: "idx_ip_customer_occ_on_ids",
        unique: true,
      )
      t.index(:customer_occurrence_id)
    end

    add_foreign_key(
      :customer_occurrences,
      :customer_occurrence_statuses,
      column: :status_id,
      validate: false,
    )
    add_foreign_key(:area_customer_occurrences, :area_occurrences, validate: false)
    add_foreign_key(:area_customer_occurrences, :customer_occurrences, validate: false)
    add_foreign_key(:email_customer_occurrences, :email_occurrences, validate: false)
    add_foreign_key(:email_customer_occurrences, :customer_occurrences, validate: false)
    add_foreign_key(:ip_customer_occurrences, :ip_occurrences, validate: false)
    add_foreign_key(:ip_customer_occurrences, :customer_occurrences, validate: false)
  end

  private

  def seed_customer_occurrence_statuses
    status_model =
      Class.new(ActiveRecord::Base) do
        self.table_name = "customer_occurrence_statuses"
        self.primary_key = "id"
      end

    status_model.create!([{ id: 0 }, { id: 1 }, { id: 2 }, { id: 3 }])
  end
end
