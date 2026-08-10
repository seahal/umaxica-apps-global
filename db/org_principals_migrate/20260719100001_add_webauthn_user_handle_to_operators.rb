# frozen_string_literal: true

# Opaque, immutable WebAuthn user handle. The internal bigint primary key was
# previously sent as user.id; a random handle removes the enumerable internal
# identifier from the ceremony without affecting account lookup.
class AddWebauthnUserHandleToOperators < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_column(:operators, :webauthn_user_handle, :string)

    say_with_time("backfill operators.webauthn_user_handle") do
      select_values("SELECT id FROM operators WHERE webauthn_user_handle IS NULL").each do |id|
        update("UPDATE operators SET webauthn_user_handle = #{connection.quote(SecureRandom.urlsafe_base64(32))} WHERE id = #{id.to_i}")
      end
    end

    add_index(:operators, :webauthn_user_handle, unique: true, algorithm: :concurrently)
    safety_assured { change_column_null(:operators, :webauthn_user_handle, false) }
  end

  def down
    remove_column(:operators, :webauthn_user_handle)
  end
end
