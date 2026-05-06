# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class ActivitiesController < ApplicationController
        auth_required!

        LOGIN_EVENT_IDS = [UserChronicleEvent::LOGGED_IN, UserChronicleEvent::LOGIN_SUCCESS].freeze
        EVENT_LABELS = {
          UserChronicleEvent::LOGGED_IN => "logged_in",
          UserChronicleEvent::LOGIN_SUCCESS => "login_success",
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

        before_action :authenticate_user!

        helper_method :activity_event_label, :activity_ip_address, :activity_context_text, :activity_occurred_at,
                      :activity_user_agent_summary, :activity_login_method

        def index
          @activities = current_user_activities.limit(100)
        rescue StandardError
          @activities = UserChronicle.none
        end

        def show
          index
          render :index
        end

        private

        # UserChronicle is currently written with numeric user.id in subject_id.
        def current_user_activities
          UserChronicle
            .where(subject_type: "User", subject_id: current_user.id, event_id: LOGIN_EVENT_IDS)
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
