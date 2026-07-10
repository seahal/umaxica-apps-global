# frozen_string_literal: true

class ConsolidateOneTimePassword < ActiveRecord::Migration[8.2]
  class UserIdentityOneTimePassword < ActiveRecord::Base
    self.table_name = "user_identity_one_time_passwords"
  end

  def change
    # Add columns from HmacBasedOneTimePassword to UserIdentityOneTimePassword
    change_table(:user_identity_one_time_passwords, bulk: true) do |t|
      t.string(:private_key, limit: 1024, null: true)
      t.datetime(:last_otp_at, null: true)
    end

    # Remove foreign key reference
    reversible do |dir|
      dir.up do
        UserIdentityOneTimePassword.reset_column_information
        UserIdentityOneTimePassword.find_each do |record|
          # Query the occurrence database for the hmac record
          occurrence_conn = ActiveRecord::Base.connection_handler.retrieve_connection("occurrence")
          hmac = occurrence_conn.execute(
            "SELECT private_key, last_otp_at FROM hmac_based_one_time_passwords WHERE id = $1",
            [record.hmac_based_one_time_password_id],
          ).first

          if hmac

            record.update_columns(
              private_key: hmac["private_key"],
              last_otp_at: hmac["last_otp_at"],
            )

          end
        end

        change_column_null(:user_identity_one_time_passwords, :private_key, false)
        change_column_null(:user_identity_one_time_passwords, :last_otp_at, false)

        remove_column(:user_identity_one_time_passwords, :hmac_based_one_time_password_id, :binary)
      end
      dir.down do
        add_column(
          :user_identity_one_time_passwords, :hmac_based_one_time_password_id, :binary, null: false,
                                                                                        default: "\x00",
        )

        change_column_null(:user_identity_one_time_passwords, :private_key, true)
        change_column_null(:user_identity_one_time_passwords, :last_otp_at, true)
      end
    end
  end
end
