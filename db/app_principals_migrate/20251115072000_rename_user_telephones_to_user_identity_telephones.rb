# frozen_string_literal: true

class RenameUserTelephonesToUserIdentityTelephones < ActiveRecord::Migration[8.2]
  def up
    return unless table_exists?(:user_telephones)

    rename_table(:user_telephones, :user_identity_telephones)

    # Check if index still has old name before renaming
    return unless index_exists?(:user_identity_telephones, :user_id, name: "index_user_telephones_on_user_id")

    rename_index(
      :user_identity_telephones,
      "index_user_telephones_on_user_id",
      "index_user_identity_telephones_on_user_id",
    )

  end

  def down
    return unless table_exists?(:user_identity_telephones)

    rename_index(
      :user_identity_telephones,
      "index_user_identity_telephones_on_user_id",
      "index_user_telephones_on_user_id",
    )
    rename_table(:user_identity_telephones, :user_telephones)
  end
end
