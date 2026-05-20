# frozen_string_literal: true

class AddUserIdentityTelephoneStatusToUserIdentityTelephones < ActiveRecord::Migration[8.2]
  def change
    add_column(
      :user_identity_telephones, :user_identity_telephone_status_id, :string, limit: 255,
                                                                              default: "UNVERIFIED", null: false,
    ) unless column_exists?(
      :user_identity_telephones, :user_identity_telephone_status_id,
    )
    add_index(:user_identity_telephones, :user_identity_telephone_status_id) unless index_exists?(
      :user_identity_telephones, :user_identity_telephone_status_id,
    )
    add_foreign_key(:user_identity_telephones, :user_identity_telephone_statuses) unless foreign_key_exists?(
      :user_identity_telephones, :user_identity_telephone_statuses,
    )
  end
end
