# typed: false
# frozen_string_literal: true

module Auth
  # Writes audit records with best-effort semantics
  # Ensures authentication success is not blocked by audit failures
  #
  # Usage:
  #   # Raises exception on failure (use in critical paths)
  #   Auth::AuditWriter.write!(audit_class, event_id, resource:, actor:, ip_address:)
  #
  #   # Returns false on failure, notifies observers (use in auth flows)
  #   Auth::AuditWriter.write(audit_class, event_id, resource:, actor:, ip_address:)
  class AuditWriter
    class AuditWriteError < StandardError; end

    # Writes audit record and raises exception on failure
    # Use this when audit failure should stop the operation
    def self.write!(audit_class, event_id, resource:, actor: nil, ip_address: nil)
      actor ||= resource

      ChronicleRecord.connected_to(role: :writing) do
        normalized_event_id = normalize_event_id(audit_class, event_id)
        audit = build_audit(
          audit_class, normalized_event_id, resource: resource, actor: actor,
                                            ip_address: ip_address,
        )

        unless audit.save
          error_message = "Audit save failed: #{audit.errors.full_messages.join(", ")}"
          Rails.logger.error("[Auth::AuditWriter] #{error_message}")
          raise AuditWriteError, error_message
        end

        audit
      end
    end

    # Writes audit record with best-effort semantics
    # Returns true on success, false on failure
    # Notifies observers on failure (via Rails.event.notify)
    # Use this in authentication flows to prevent audit failures from blocking auth
    def self.write(audit_class, event_id, resource:, actor: nil, ip_address: nil)
      write!(audit_class, event_id, resource: resource, actor: actor, ip_address: ip_address)
      true
    rescue StandardError => e
      # Observe the failure without blocking authentication
      Rails.logger.error("[Auth::AuditWriter] Audit write failed (best-effort): #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace

      Rails.event.notify(
        "authentication.audit.failed",
        event_id: event_id,
        resource_type: resource.class.name,
        resource_id: resource.id,
        error_class: e.class.name,
        error_message: e.message,
      )

      false
    end

    # Builds audit record without saving
    def self.build_audit(audit_class, event_id, resource:, actor:, ip_address:)
      audit = audit_class.new(
        actor: actor,
        event_id: event_id,
        ip_address: ip_address,
        occurred_at: Time.current,
      )

      if actor
        audit.actor_id = actor.id
        audit.actor_type = actor.class.name
      end

      # Set resource using the appropriate setter method
      # For UserChronicle: user= or subject_id=/subject_type=
      # For StaffChronicle: staff= or subject_id=/subject_type=
      resource_type = infer_resource_type(audit_class, resource)
      if audit.respond_to?("#{resource_type}=")
        audit.public_send("#{resource_type}=", resource)
      else
        # Fallback to subject_id/subject_type
        audit.subject_id = resource.id.to_s
        audit.subject_type = resource.class.name
      end

      audit
    end

    # Infers resource type from audit class name
    # UserChronicle -> "user", StaffChronicle -> "staff"
    def self.infer_resource_type(audit_class, resource)
      # Try to extract from audit class name (UserChronicle -> user)
      class_name = audit_class.name.demodulize
      if class_name =~ /^(\w+)Activity$/
        Regexp.last_match(1).downcase
      else
        # Fallback to resource class name
        resource.class.name.downcase
      end
    end

    private_class_method :infer_resource_type

    def self.normalize_event_id(audit_class, event_id)
      return event_id if event_id.is_a?(Integer)
      return event_id unless event_id.is_a?(String) || event_id.is_a?(Symbol)

      event_id_map_for(audit_class).fetch(event_id.to_s, event_id)
    end

    def self.event_id_map_for(audit_class)
      case audit_class.name
      when "UserChronicle"
        {
          "LOGGED_IN" => UserChronicleEvent::LOGGED_IN,
          "LOGGED_OUT" => UserChronicleEvent::LOGGED_OUT,
          "LOGIN_FAILED" => UserChronicleEvent::LOGIN_FAILED,
          "TOKEN_REFRESHED" => UserChronicleEvent::TOKEN_REFRESHED,
        }
      when "StaffChronicle"
        {
          "LOGGED_IN" => StaffChronicleEvent::LOGGED_IN,
          "LOGGED_OUT" => StaffChronicleEvent::LOGGED_OUT,
          "LOGIN_FAILED" => StaffChronicleEvent::LOGIN_FAILED,
          "TOKEN_REFRESHED" => StaffChronicleEvent::TOKEN_REFRESHED,
        }
      when "AppPreferenceChronicle"
        {
          "REFRESH_TOKEN_ROTATED" => AppPreferenceChronicleEvent::REFRESH_TOKEN_ROTATED,
          "UPDATE_PREFERENCE_COOKIE" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_COOKIE,
          "UPDATE_PREFERENCE_THEME" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_THEME,
          "RESET_BY_USER_DECISION" => AppPreferenceChronicleEvent::RESET_BY_USER_DECISION,
          "UPDATE_PREFERENCE_TIMEZONE" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_TIMEZONE,
          "UPDATE_PREFERENCE_REGION" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_REGION,
          "UPDATE_PREFERENCE_LANGUAGE" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_LANGUAGE,
          "CREATE_NEW_PREFERENCE_TOKEN" => AppPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
        }
      when "ComPreferenceChronicle"
        {
          "CREATE_NEW_PREFERENCE_TOKEN" => ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
          "REFRESH_TOKEN_ROTATED" => ComPreferenceChronicleEvent::REFRESH_TOKEN_ROTATED,
          "UPDATE_PREFERENCE_COOKIE" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_COOKIE,
          "UPDATE_PREFERENCE_LANGUAGE" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_LANGUAGE,
          "UPDATE_PREFERENCE_TIMEZONE" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_TIMEZONE,
          "RESET_BY_USER_DECISION" => ComPreferenceChronicleEvent::RESET_BY_USER_DECISION,
          "UPDATE_PREFERENCE_REGION" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_REGION,
          "UPDATE_PREFERENCE_THEME" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_THEME,
        }
      when "OrgPreferenceChronicle"
        {
          "CREATE_NEW_PREFERENCE_TOKEN" => OrgPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
          "REFRESH_TOKEN_ROTATED" => OrgPreferenceChronicleEvent::REFRESH_TOKEN_ROTATED,
          "UPDATE_PREFERENCE_COOKIE" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_COOKIE,
          "UPDATE_PREFERENCE_LANGUAGE" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_LANGUAGE,
          "UPDATE_PREFERENCE_TIMEZONE" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_TIMEZONE,
          "RESET_BY_USER_DECISION" => OrgPreferenceChronicleEvent::RESET_BY_USER_DECISION,
          "UPDATE_PREFERENCE_REGION" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_REGION,
          "UPDATE_PREFERENCE_THEME" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_THEME,
        }
      else
        {}
      end
    end

    private_class_method :event_id_map_for
    private_class_method :normalize_event_id
  end
end
