# typed: false
# frozen_string_literal: true

module PrivacyErasureRequestFlow
  extend ActiveSupport::Concern
  include WithdrawalCeremonyAuthentication

  private

  def render_privacy_erasure_new(subject)
    @privacy_request = latest_privacy_request_for(subject)
  end

  def create_privacy_erasure_request!(subject)
    return render_privacy_erasure_forbidden unless subject.withdrawal_in_progress? || subject.terminated?

    privacy_request = privacy_request_class.create!(
      privacy_subject_key => subject,
      :request_kind => "erasure",
      :jurisdiction => privacy_erasure_jurisdiction,
      :request_source => "self_service",
    )
    create_processor_notifications!(privacy_request)
    WithdrawalOccurrenceRecording.record!(
      subject: subject,
      event_type: "privacy_erasure.requested",
      request: request,
      context: { privacy_request_public_id: privacy_request.public_id },
    )

    safe_redirect_to(privacy_erasure_status_path, fallback: privacy_erasure_new_path, status: :see_other)
  end

  def render_privacy_erasure_status(subject)
    @privacy_request = latest_privacy_request_for(subject)
  end

  def latest_privacy_request_for(subject)
    privacy_requests_for(subject).order(created_at: :desc).first
  end

  def privacy_requests_for(subject)
    case subject
    when Client then subject.client_privacy_requests
    when Visitor then subject.visitor_privacy_requests
    else
      raise ArgumentError, "unsupported privacy erasure subject: #{subject.class.name}"
    end
  end

  def create_processor_notifications!(privacy_request)
    notification_class = processor_notification_class
    ProcessorErasureNotificationState::PROCESSOR_KEYS.each do |processor_key|
      notification = notification_class.find_or_create_by!(
        processor_privacy_request_key => privacy_request,
        :processor_key => processor_key,
      )
      ProcessorErasureNotificationJob.perform_later(
        surface: privacy_erasure_surface.to_s,
        public_id: notification.public_id,
      )
    end
  end

  def privacy_erasure_jurisdiction
    value = params[:jurisdiction].presence || "unknown"
    return value if PrivacyRequestState::JURISDICTIONS.include?(value)

    "unknown"
  end

  def render_privacy_erasure_forbidden
    render plain: I18n.t("privacy_erasure.forbidden"),
           status: :forbidden
  end
end
