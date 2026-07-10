# frozen_string_literal: true

class SeedIdentityStatuses < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    safety_assured do
      # HandleAssignmentStatus
      upsert_table(
        'handle_assignment_statuses', [
          { id: 'ACTIVE', key: 'ACTIVE', name: 'Active' },
        ],
      )

      # HandleStatus
      upsert_table(
        'handle_statuses', [
          { id: 'ACTIVE', key: 'ACTIVE', name: 'Active' },
        ],
      )

      # StaffIdentityStatus
      upsert_table(
        'staff_identity_statuses', [
          { id: "NEYO" },
          { id: "ALIVE" },
          { id: "PRE_WITHDRAWAL_CONDITION" },
          { id: "WITHDRAWAL_COMPLETED" },
        ],
      )

      # StaffIdentityEmailStatus
      upsert_table(
        'staff_identity_email_statuses', [
          { id: "NEYO" },
          { id: "UNVERIFIED" },
          { id: "VERIFIED" },
          { id: "SUSPENDED" },
          { id: "DELETED" },
        ],
      )

      # StaffIdentitySecretStatus
      upsert_table(
        'staff_identity_secret_statuses', [
          { id: "ACTIVE" },
          { id: "USED" },
          { id: "EXPIRED" },
          { id: "REVOKED" },
          { id: "DELETED" },
        ],
      )

      # StaffIdentityTelephoneStatus
      upsert_table(
        'staff_identity_telephone_statuses', [
          { id: "NEYO" },
          { id: "UNVERIFIED" },
          { id: "VERIFIED" },
          { id: "SUSPENDED" },
          { id: "DELETED" },
        ],
      )

      # UserIdentityEmailStatus
      upsert_table(
        'user_identity_email_statuses', [
          { id: "UNVERIFIED_WITH_SIGN_UP" },
          { id: "VERIFIED_WITH_SIGN_UP" },
          { id: "UNVERIFIED" },
          { id: "ALIVE" },
          { id: "SUSPENDED" },
          { id: "DELETED" },
        ],
      )

      # UserIdentityOneTimePasswordStatus
      upsert_table(
        'user_identity_one_time_password_statuses', [
          { id: "ACTIVE" },
          { id: "INACTIVE" },
          { id: "REVOKED" },
          { id: "DELETED" },
        ],
      )

      # UserIdentityPasskeyStatus
      upsert_table(
        'user_identity_passkey_statuses', [
          { id: "ACTIVE" },
          { id: "DISABLED" },
          { id: "DELETED" },
        ],
      )

      # UserIdentitySecretStatus
      upsert_table(
        'user_identity_secret_statuses', [
          { id: "ACTIVE" },
          { id: "USED" },
          { id: "EXPIRED" },
          { id: "REVOKED" },
          { id: "DELETED" },
        ],
      )

      # UserIdentitySocialAppleStatus
      upsert_table(
        'user_identity_social_apple_statuses', [
          { id: "ACTIVE" },
          { id: "REVOKED" },
          { id: "DELETED" },
        ],
      )

      # UserIdentitySocialGoogleStatus
      upsert_table(
        'user_identity_social_google_statuses', [
          { id: "ACTIVE" },
          { id: "REVOKED" },
          { id: "DELETED" },
        ],
      )

      # UserIdentityStatus
      upsert_table(
        'user_identity_statuses', [
          { id: "NEYO" },
          { id: "ALIVE" },
          { id: "VERIFIED_WITH_SIGN_UP" },
          { id: "PRE_WITHDRAWAL_CONDITION" },
          { id: "WITHDRAWAL_COMPLETED" },
        ],
      )

      # UserIdentityTelephoneStatus
      upsert_table(
        'user_identity_telephone_statuses', [
          { id: "NEYO" },
          { id: "UNVERIFIED" },
          { id: "VERIFIED" },
          { id: "SUSPENDED" },
          { id: "DELETED" },
          { id: "ACTIVE" },
        ],
      )
    end
  end

  def down
    safety_assured do
      %w(
        handle_assignment_statuses
        handle_statuses
        staff_identity_statuses
        staff_identity_email_statuses
        staff_identity_secret_statuses
        staff_identity_telephone_statuses
        user_identity_email_statuses
        user_identity_one_time_password_statuses
        user_identity_passkey_statuses
        user_identity_secret_statuses
        user_identity_social_apple_statuses
        user_identity_social_google_statuses
        user_identity_statuses
        user_identity_telephone_statuses
      ).each do |table|
        # No-op: intentionally left blank.
      end
    end
  end

  private

  def upsert_table(table_name, rows)
    # No-op: data seeding moved to fixtures.
  end
end
