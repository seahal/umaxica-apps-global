# typed: false
# frozen_string_literal: true

# Solid Queue 1.7 ships batches as an update migration and requires it from 2.0, which is what
# the pending-migration deprecation warning in the development log was reporting.
#
# Two deviations from the upstream template
# (solid_queue-1.7.0/lib/generators/solid_queue/update/templates/db/add_batches_to_solid_queue.rb):
# the migration version tracks this application's `load_defaults(8.2)` rather than the gem's 7.1,
# and the index on the already-populated `solid_queue_jobs` is built CONCURRENTLY. Building it
# inline holds a lock on the busiest table in this database for the length of the build, which
# `StrongMigrations` rejects. Concurrent builds cannot run inside a transaction, hence
# `disable_ddl_transaction!`; every statement keeps the upstream `if_not_exists:` guard, so a run
# that fails partway outside a transaction is safe to repeat.
class AddBatchesToSolidQueue < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    # Fresh installs create all of this with the base schema, so skip
    # anything that already exists
    add_column(:solid_queue_jobs, :batch_id, :bigint, if_not_exists: true)
    add_index(:solid_queue_jobs, :batch_id, algorithm: :concurrently, if_not_exists: true)

    create_table(:solid_queue_batches, if_not_exists: true) do |t|
      t.string(:active_job_batch_id)
      t.string(:description)
      t.text(:on_finish)
      t.text(:on_success)
      t.text(:on_failure)
      t.text(:metadata)
      t.integer(:total_jobs, default: 0, null: false)
      t.integer(:completed_jobs, default: 0, null: false)
      t.integer(:failed_jobs, default: 0, null: false)
      t.datetime(:enqueued_at)
      t.datetime(:finished_at)
      t.datetime(:failed_at)
      t.datetime(:created_at, null: false)
      t.datetime(:updated_at, null: false)

      t.index(:active_job_batch_id, unique: true)
      t.index(:finished_at)
    end

    create_table(:solid_queue_batch_executions, if_not_exists: true) do |t|
      t.bigint(:job_id, null: false)
      t.bigint(:batch_id, null: false)
      t.datetime(:created_at, null: false)

      t.index(:job_id, unique: true)
      t.index(:batch_id)
      t.foreign_key(:solid_queue_batches, column: :batch_id, on_delete: :cascade)
      t.foreign_key(:solid_queue_jobs, column: :job_id, on_delete: :cascade)
    end
  end
end
