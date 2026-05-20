# frozen_string_literal: true

class EnforceUniqueUserOauths < ActiveRecord::Migration[8.2]
  def change
    if table_exists?(:user_google_auths)
      remove_index(:user_google_auths, :user_id) if index_exists?(:user_google_auths, :user_id)
      add_index(
        :user_google_auths, :user_id,
        unique: true,
        where: "user_id IS NOT NULL",
        name: "index_user_google_auths_on_user_id_unique",
      )
    end

    return unless table_exists?(:user_apple_auths)

    remove_index(:user_apple_auths, :user_id) if index_exists?(:user_apple_auths, :user_id)
    add_index(
      :user_apple_auths, :user_id,
      unique: true,
      where: "user_id IS NOT NULL",
      name: "index_user_apple_auths_on_user_id_unique",
    )

  end
end
