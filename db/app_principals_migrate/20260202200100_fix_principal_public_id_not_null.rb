# frozen_string_literal: true

class FixPrincipalPublicIdNotNull < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      # 1. User.public_id NOT NULL
      if table_exists?(:users) && column_exists?(:users, :public_id)
        execute("UPDATE users SET public_id = '' WHERE public_id IS NULL OR public_id = ''")
        execute("ALTER TABLE users ALTER COLUMN public_id SET NOT NULL")
      end

      # 2. UserOneTimePassword.public_id NOT NULL
      if table_exists?(:user_one_time_passwords) && column_exists?(:user_one_time_passwords, :public_id)
        execute("UPDATE user_one_time_passwords SET public_id = '' WHERE public_id IS NULL")
        execute("ALTER TABLE user_one_time_passwords ALTER COLUMN public_id SET NOT NULL")
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
