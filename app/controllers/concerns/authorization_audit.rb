# typed: false
# frozen_string_literal: true

# Concern for auditing authorization failures
# Records when users/staff attempt unauthorized actions
module AuthorizationAudit
  extend ActiveSupport::Concern

  included do
    include Common::Redirect

    # Log authorization failures for audit purposes
    if respond_to?(:rescue_from)
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
    end
  end

  private

  def handle_authorization_error(exception)
    # Log the authorization failure
    log_authorization_failure(exception)

    # Respond based on request format
    respond_to do |format|
      format.html do
        flash[:alert] = I18n.t("errors.messages.not_authorized")
        safe_redirect_back_or_to(root_path)
      end
      format.json do
        render json: { error: "Unauthorized" }, status: :forbidden
      end
    end
  end

  def log_authorization_failure(exception)
    actor = current_user_or_staff
    return unless actor

    log_data = build_log_data(actor, exception)

    # Log the authorization failure event
    Rails.event.notify("authorization.failure", log_data)

    create_audit_record(actor, log_data)
  rescue StandardError => e
    # Don't let audit logging break the application
    Rails.logger.error("Authorization audit logging failed: #{e.message}")
    Rails.event.notify("authorization.failure_log.failed", error_message: e.message)
  end

  def build_log_data(actor, exception)
    {
      actor_type: actor.class.name,
      actor_id: actor.id,
      action: action_name,
      controller: controller_name,
      policy: exception.policy.class.name,
      query: exception.rule,
      record_type: exception.policy.record&.class&.name,
      record_id: exception.policy.record&.id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      timestamp: Time.current,
    }
  end

  def create_audit_record(actor, log_data)
    # Create audit record if actor is User or Staff
    if actor.is_a?(User)
      create_user_authorization_audit(actor, log_data)
    elsif actor.is_a?(Staff)
      create_staff_authorization_audit(actor, log_data)
    end
  end

  def create_user_authorization_audit(user, log_data)
    audit = UserChronicle.new(
      actor: user,
      event_id: UserChronicleEvent::AUTHORIZATION_FAILED,
      ip_address: log_data[:ip_address],
      occurred_at: log_data[:timestamp],
    )
    audit.user = user
    audit.save!
  rescue ActiveRecord::RecordInvalid => e
    # Event ID might not exist in the database yet
    Rails.event.notify("authorization.audit.user_creation_failed", error_message: e.message)
  end

  def create_staff_authorization_audit(staff, log_data)
    audit = StaffChronicle.new(
      actor: staff,
      event_id: StaffChronicleEvent::AUTHORIZATION_FAILED,
      ip_address: log_data[:ip_address],
      occurred_at: log_data[:timestamp],
    )
    audit.staff = staff
    audit.save!
  rescue ActiveRecord::RecordInvalid => e
    # Event ID might not exist in the database yet
    Rails.event.notify("authorization.audit.staff_creation_failed", error_message: e.message)
  end

  def current_user_or_staff
    # Try current_user first (for User controllers)
    return current_user if respond_to?(:current_user) && current_user

    # Try current_staff (for Staff controllers)
    return current_staff if respond_to?(:current_staff) && current_staff

    nil
  end
end
