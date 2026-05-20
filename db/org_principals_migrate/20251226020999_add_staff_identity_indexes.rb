# frozen_string_literal: true

class AddStaffIdentityIndexes < ActiveRecord::Migration[8.2]
  def change
    # Lower ID Unique Indexes for Status Tables
    add_index(
      :staff_identity_statuses, "lower(id)", unique: true, name: "index_staff_identity_statuses_on_lower_id",
                                             if_not_exists: true,
    )
    add_index(
      :staff_identity_email_statuses, "lower(id)", unique: true,
                                                   name: "index_staff_identity_email_statuses_on_lower_id", if_not_exists: true,
    )
    add_index(
      :staff_identity_telephone_statuses, "lower(id)", unique: true,
                                                       name: "index_staff_identity_telephone_statuses_on_lower_id", if_not_exists: true,
    )
    add_index(
      :staff_identity_secret_statuses, "lower(id)", unique: true,
                                                    name: "index_staff_identity_secret_statuses_on_lower_id", if_not_exists: true,
    )

    # UserIdentityTelephone lower(number)
    add_index(
      :staff_identity_telephones, "lower(number)", name: "index_staff_identity_telephones_on_lower_number",
                                                   if_not_exists: true,
    )
    add_index(
      :staff_identity_emails, "lower(address)", name: "index_staff_identity_emails_on_lower_address",
                                                if_not_exists: true,
    )
  end
end
