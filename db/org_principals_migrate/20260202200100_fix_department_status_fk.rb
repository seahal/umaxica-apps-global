# frozen_string_literal: true

class FixDepartmentStatusFk < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      if table_exists?(:departments) && table_exists?(:department_statuses)
        # Check if FK already exists
        fk_exists = connection.select_value(<<~SQL.squish)
          SELECT 1 FROM pg_constraint#{" "}
          WHERE conrelid = 'departments'::regclass#{" "}
            AND confrelid = 'department_statuses'::regclass
        SQL

        unless fk_exists
          # Ensure department_status_id is bigint
          if column_exists?(:departments, :department_status_id)
            current_type = connection.select_value(<<~SQL.squish)
              SELECT data_type FROM information_schema.columns#{" "}
              WHERE table_name = 'departments' AND column_name = 'department_status_id'
            SQL

            if current_type != 'bigint'
              execute("TRUNCATE TABLE departments CASCADE")
              execute("ALTER TABLE departments ALTER COLUMN department_status_id DROP DEFAULT")
              execute("ALTER TABLE departments ALTER COLUMN department_status_id TYPE bigint USING 0")
              execute("ALTER TABLE departments ALTER COLUMN department_status_id SET DEFAULT 0")
              execute("ALTER TABLE departments ALTER COLUMN department_status_id SET NOT NULL")
            end

            # Add FK
            execute(<<~SQL.squish)
              ALTER TABLE departments#{" "}
              ADD CONSTRAINT fk_departments_on_department_status_id#{" "}
              FOREIGN KEY (department_status_id) REFERENCES department_statuses (id)
            SQL
            Rails.logger.debug("Added FK: departments.department_status_id -> department_statuses.id")
          end
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
