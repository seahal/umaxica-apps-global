# frozen_string_literal: true

class AddTestSeederIdentityData < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      # Insert identity statuses needed by TestSeeder
      seed_ids = {
        "user_identity_statuses" => %w(NEYO ALIVE VERIFIED_WITH_SIGN_UP PRE_WITHDRAWAL_CONDITION WITHDRAWAL_COMPLETED),
        "staff_identity_statuses" => %w(NEYO ALIVE PRE_WITHDRAWAL_CONDITION WITHDRAWAL_COMPLETED),
        "user_identity_email_statuses" => %w(NEYO UNVERIFIED_WITH_SIGN_UP VERIFIED_WITH_SIGN_UP UNVERIFIED ALIVE
                                             SUSPENDED DELETED),
        "staff_identity_email_statuses" => %w(NEYO UNVERIFIED VERIFIED SUSPENDED DELETED),
        "user_identity_telephone_statuses" => %w(NEYO UNVERIFIED VERIFIED SUSPENDED DELETED ACTIVE),
        "staff_identity_telephone_statuses" => %w(NEYO UNVERIFIED VERIFIED SUSPENDED DELETED),
        "user_identity_social_google_statuses" => %w(ACTIVE REVOKED DELETED),
        "user_identity_social_apple_statuses" => %w(ACTIVE REVOKED DELETED),
        "user_identity_passkey_statuses" => %w(ACTIVE DISABLED DELETED),
        "user_identity_one_time_password_statuses" => %w(ACTIVE INACTIVE REVOKED DELETED),
        "user_identity_secret_statuses" => %w(ACTIVE USED EXPIRED REVOKED DELETED),
        "staff_identity_secret_statuses" => %w(ACTIVE USED EXPIRED REVOKED DELETED),
        "user_occurrence_statuses" => %w(NEYO ACTIVE),
      }

      seed_ids.each do |table_name, ids|
        next unless table_exists?(table_name)

        ids.each do |id|
          cols = []
          vals = []

          cols << "id"
          vals << connection.quote(id)

          if column_exists?(table_name, :active)
            cols << "active"
            vals << "TRUE"
          end

          if column_exists?(table_name, :position)
            cols << "position"
            vals << "0"
          end

          if column_exists?(table_name, :created_at)
            cols << "created_at"
            vals << "CURRENT_TIMESTAMP"
          end

          if column_exists?(table_name, :updated_at)
            cols << "updated_at"
            vals << "CURRENT_TIMESTAMP"
          end

          if column_exists?(table_name, :description)
            cols << "description"
            vals << connection.quote(id)
          end

          # Specific fix for user_occurrence_statuses requiring expires_at
          if table_name == "user_occurrence_statuses" && column_exists?(table_name, :expires_at)
            cols << "expires_at"
            vals << "(CURRENT_TIMESTAMP + INTERVAL '1 day')"
          end
        end
      end

      # Insert audit events and levels
      levels = %w(NEYO NONE INFO WARN ERROR)
      user_events = %w(
        LOGIN_SUCCESS LOGIN_FAILURE LOGGED_IN LOGGED_OUT LOGIN_FAILED
        TOKEN_REFRESHED SIGNED_UP_WITH_EMAIL SIGNED_UP_WITH_TELEPHONE
        SIGNED_UP_WITH_APPLE AUTHORIZATION_FAILED
      )
      staff_events = %w(
        LOGIN_SUCCESS LOGIN_FAILURE LOGGED_IN LOGGED_OUT LOGIN_FAILED
        AUTHORIZATION_FAILED
      )

      seed_map = {
        "user_identity_audit_levels" => levels,
        "staff_identity_audit_levels" => levels,
        "user_identity_audit_events" => user_events,
        "staff_identity_audit_events" => staff_events,
      }

      seed_map.each do |table_name, event_ids|
        next unless table_exists?(table_name)

        event_ids.each do |id|
          cols = []
          vals = []

          cols << "id"
          vals << connection.quote(id)

          if column_exists?(table_name, :created_at)
            cols << "created_at"
            vals << "CURRENT_TIMESTAMP"
          end

          if column_exists?(table_name, :updated_at)
            cols << "updated_at"
            vals << "CURRENT_TIMESTAMP"
          end
        end
      end

      # Insert nil/dummy User for FK constraints
      if table_exists?("users")
        nil_uuid = "00000000-0000-0000-0000-000000000000"
        nil_public_id = "000000000000000000000"

        cols = %w(id created_at updated_at)
        vals = [
          connection.quote(nil_uuid),
          "CURRENT_TIMESTAMP",
          "CURRENT_TIMESTAMP",
        ]

        if column_exists?("users", :public_id)
          cols << "public_id"
          vals << connection.quote(nil_public_id)
        end

        if column_exists?("users", :email)
          cols << "email"
          vals << connection.quote("test@example.com")
        end

        if column_exists?("users", :user_identity_status_id)
          cols << "user_identity_status_id"
          vals << connection.quote("ALIVE")
        end

      end

      # Insert specific Google Identity seeding with fixed expires_at
      if table_exists?("user_identity_social_googles")
        user_id = nil
        if table_exists?("users")
          result = connection.select_value("SELECT id FROM users LIMIT 1")
          if result.nil?
            # Create a user if none exists
            nil_public_id = "000000000000000000000"
            cols = %w(public_id created_at updated_at)
            vals = [connection.quote(nil_public_id), "CURRENT_TIMESTAMP", "CURRENT_TIMESTAMP"]

            if column_exists?("users", :user_identity_status_id)
              cols << "user_identity_status_id"
              vals << connection.quote("ALIVE")
            end

            user_id = connection.select_value("SELECT id FROM users WHERE public_id = #{connection.quote(nil_public_id)}")
          else
            user_id = result
          end
        end

        cols = %w(uid provider token expires_at created_at updated_at)
        vals = [
          connection.quote("uid-1"),
          connection.quote("google_oauth2"),
          connection.quote("token-1"),
          "2147483647",
          "CURRENT_TIMESTAMP",
          "CURRENT_TIMESTAMP",
        ]

        if column_exists?("user_identity_social_googles", :user_id) && user_id
          cols << "user_id"
          vals << connection.quote(user_id)
        end

        if column_exists?("user_identity_social_googles", :user_identity_social_google_status_id)
          cols << "user_identity_social_google_status_id"
          vals << connection.quote("ACTIVE")
        end

      end
    end
  end

  def down
    # No-op - we don't want to delete reference data
  end
end
