# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class ActivitiesController < PrivateController
        AUTHENTICATION_MODE = :private

        VISIBLE_EVENT_IDS = [
          ClientChronicleEvent::LOGGED_IN,
          ClientChronicleEvent::LOGIN_SUCCESS,
          ClientChronicleEvent::LOGGED_OUT,
          ClientChronicleEvent::LOGOUT,
          ClientChronicleEvent::SIGNED_UP_WITH_APPLE,
          ClientChronicleEvent::SIGNED_UP_WITH_EMAIL,
          ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE,
          ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE,
          ClientChronicleEvent::SOCIAL_LINKED,
          ClientChronicleEvent::SOCIAL_UNLINKED,
          ClientChronicleEvent::SESSION_REVOKED,
          ClientChronicleEvent::EMAIL_REGISTERED,
          ClientChronicleEvent::EMAIL_REMOVED,
          ClientChronicleEvent::TELEPHONE_REGISTERED,
          ClientChronicleEvent::TELEPHONE_REMOVED,
          ClientChronicleEvent::TOTP_ENABLED,
          ClientChronicleEvent::PASSKEY_REGISTERED,
          ClientChronicleEvent::USER_SECRET_CREATED,
          ClientChronicleEvent::RECOVERY_CODES_GENERATED,
        ].freeze
        EVENT_LABELS = {
          ClientChronicleEvent::LOGGED_IN => "logged_in",
          ClientChronicleEvent::LOGIN_SUCCESS => "login_success",
          ClientChronicleEvent::LOGGED_OUT => "logged_out",
          ClientChronicleEvent::LOGOUT => "logout",
          ClientChronicleEvent::SIGNED_UP_WITH_APPLE => "signed_up_with_apple",
          ClientChronicleEvent::SIGNED_UP_WITH_EMAIL => "signed_up_with_email",
          ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE => "signed_up_with_google",
          ClientChronicleEvent::SIGNED_UP_WITH_TELEPHONE => "signed_up_with_telephone",
          ClientChronicleEvent::SOCIAL_LINKED => "social_linked",
          ClientChronicleEvent::SOCIAL_UNLINKED => "social_unlinked",
          ClientChronicleEvent::SESSION_REVOKED => "session_revoked",
          ClientChronicleEvent::EMAIL_REGISTERED => "email_registered",
          ClientChronicleEvent::EMAIL_REMOVED => "email_removed",
          ClientChronicleEvent::TELEPHONE_REGISTERED => "telephone_registered",
          ClientChronicleEvent::TELEPHONE_REMOVED => "telephone_removed",
          ClientChronicleEvent::TOTP_ENABLED => "totp_enabled",
          ClientChronicleEvent::PASSKEY_REGISTERED => "passkey_registered",
          ClientChronicleEvent::USER_SECRET_CREATED => "user_secret_created",
          ClientChronicleEvent::RECOVERY_CODES_GENERATED => "recovery_codes_generated",
        }.freeze
        SENSITIVE_CONTEXT_PATTERNS = %w(
          user_agent
          authorization
          token
          secret
          code
          email
          telephone
          phone
          otp
        ).freeze

        before_action :authenticate_client!

        helper_method :activity_event_label, :activity_ip_address, :activity_context_text, :activity_occurred_at,
                      :activity_user_agent_summary, :activity_login_method

        def index
          @activities = current_client_activities.limit(100)
        rescue StandardError
          @activities = ClientChronicle.none
        end

        def show
          index
          render :index
        end

        private

        # ClientChronicle is currently written with numeric user.id in subject_id.
        def current_client_activities
          ClientChronicle
            .includes(:user_chronicle_event)
            .where(event_id: VISIBLE_EVENT_IDS)
            .where(
              ClientChronicle.arel_table[:subject_type].eq("Client")
                .and(ClientChronicle.arel_table[:subject_id].eq(current_client.id))
                .or(
                  ClientChronicle.arel_table[:actor_type].eq("Client")
                    .and(ClientChronicle.arel_table[:actor_id].eq(current_client.id)),
                ),
            )
            .order(Arel.sql("COALESCE(occurred_at, created_at) DESC"))
        end

        def activity_occurred_at(activity)
          activity.occurred_at || activity.created_at
        end

        def activity_event_label(activity)
          key = EVENT_LABELS[activity.event_id]
          return t(
            "sign.app.configuration.activity.events.unknown",
            event_id: activity.event_id,
          ) if key.blank?

          I18n.t("sign.app.configuration.activity.events." + key)
        end

        def activity_ip_address(activity)
          raw = activity.ip_address.to_s
          return "-" if raw.blank?

          parts = raw.split(".")
          return raw unless parts.size == 4

          "#{parts[0]}.#{parts[1]}.#{parts[2]}.x"
        end

        def activity_context_text(activity)
          context = activity.context
          return "{}" unless context.is_a?(Hash)

          filtered =
            context
              .deep_stringify_keys
              .reject { |key, _| sensitive_context_key?(key) }

          JSON.generate(filtered)
        rescue StandardError
          "{}"
        end

        def sensitive_context_key?(key)
          normalized = key.to_s.downcase
          SENSITIVE_CONTEXT_PATTERNS.any? { |pattern| normalized.include?(pattern) }
        end

        def activity_user_agent_summary(activity)
          user_agent = activity_context_value(activity, "user_agent")
          return "-" if user_agent.blank?

          browser = detect_browser(user_agent)
          device = detect_device_type(user_agent)
          "#{browser} / #{device}"
        end

        def activity_login_method(activity)
          method = activity_context_value(
            activity,
            "auth_method",
          ) || activity_context_value(activity, "method")
          return "-" if method.blank?

          provider = activity_context_value(activity, "provider")
          return provider.to_s if method.to_s == "social" && provider.present?

          method.to_s
        end

        def activity_context_value(activity, key)
          context = activity.context
          return nil unless context.is_a?(Hash)

          context.deep_stringify_keys[key]
        end

        def detect_browser(user_agent)
          ua = user_agent.to_s
          return "Edge" if ua.include?("Edg/")
          return "Chrome" if ua.include?("Chrome/")
          return "Safari" if ua.include?("Safari/") && ua.exclude?("Chrome/")
          return "Firefox" if ua.include?("Firefox/")

          "Other"
        end

        def detect_device_type(user_agent)
          ua = user_agent.to_s
          return "Mobile" if ua.match?(/Mobile|iPhone|Android/i)
          return "Tablet" if ua.match?(/iPad|Tablet/i)

          "Desktop"
        end
      end
    end
  end
end
