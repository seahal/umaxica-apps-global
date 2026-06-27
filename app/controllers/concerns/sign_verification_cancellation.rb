# typed: false
# frozen_string_literal: true

module SignVerificationCancellation
  extend ActiveSupport::Concern

  def create
    acme_completion_state_present = acme_step_up_completion_state?
    csrf_token = acme_step_up_completion_csrf_token
    scope = current_step_up_session&.scope
    return_to = current_step_up_session&.return_to
    cancel_local_step_up_state!

    if acme_completion_state_present
      render(
        "sign/shared/step_up_cancellation",
        locals: {
          cancellation_url: acme_step_up_cancellation_url_for(step_up_ceremony_surface),
          csrf_token: csrf_token,
          ri: params[:ri],
          scope: scope,
          return_to: return_to,
        },
      )
    else
      safe_redirect_to(
        verification_cancellation_fallback_path,
        fallback: verification_cancellation_fallback_path,
        status: :see_other,
      )
    end
  end

  private

  def cancel_local_step_up_state!
    clear_step_up_state! if respond_to?(:clear_step_up_state!, true)
    destroy_current_step_up_session! if respond_to?(:destroy_current_step_up_session!, true)
    clear_acme_step_up_completion_state! if respond_to?(:clear_acme_step_up_completion_state!, true)
  end

  def acme_step_up_cancellation_url_for(surface)
    case surface.to_s
    when "app"
      cancellation_base_app_verification_url(host: ENV.fetch("BASE_SERVICE_URL", "www.app.localhost"))
    when "com"
      cancellation_base_com_verification_url(host: ENV.fetch("BASE_CORPORATE_URL", "www.com.localhost"))
    when "org"
      cancellation_base_org_verification_url(host: ENV.fetch("BASE_STAFF_URL", "www.org.localhost"))
    else
      raise NotImplementedError, "unsupported step-up surface: #{surface}"
    end
  end

  def verification_cancellation_fallback_path
    raise NotImplementedError, "#{self.class} must define #verification_cancellation_fallback_path"
  end
end
