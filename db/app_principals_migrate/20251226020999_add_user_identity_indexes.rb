# frozen_string_literal: true

class AddUserIdentityIndexes < ActiveRecord::Migration[8.2]
  def change
    # Lower ID Unique Indexes for Status Tables
    add_index(
      :user_identity_statuses, "lower(id)", unique: true, name: "index_user_identity_statuses_on_lower_id",
                                            if_not_exists: true,
    )
    add_index(
      :user_identity_telephone_statuses, "lower(id)", unique: true,
                                                      name: "index_user_identity_telephone_statuses_on_lower_id", if_not_exists: true,
    )
    add_index(
      :user_identity_email_statuses, "lower(id)", unique: true,
                                                  name: "index_user_identity_email_statuses_on_lower_id", if_not_exists: true,
    )
    add_index(
      :user_identity_one_time_password_statuses, "lower(id)", unique: true,
                                                              name: "index_user_identity_otp_statuses_on_lower_id", if_not_exists: true,
    )
    add_index(
      :user_identity_passkey_statuses, "lower(id)", unique: true,
                                                    name: "index_user_identity_passkey_statuses_on_lower_id", if_not_exists: true,
    )
    add_index(
      :user_identity_secret_statuses, "lower(id)", unique: true,
                                                   name: "index_user_identity_secret_statuses_on_lower_id", if_not_exists: true,
    )
    add_index(
      :user_identity_social_apple_statuses, "lower(id)", unique: true,
                                                         name: "index_user_identity_apple_statuses_on_lower_id", if_not_exists: true,
    )
    add_index(
      :user_identity_social_google_statuses, "lower(id)", unique: true,
                                                          name: "index_user_identity_google_statuses_on_lower_id", if_not_exists: true,
    )

    # UserIdentityTelephone lower(number)
    add_index(
      :user_identity_telephones, "lower(number)", name: "index_user_identity_telephones_on_lower_number",
                                                  if_not_exists: true,
    )
  end
end
