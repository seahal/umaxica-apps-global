# typed: false
# frozen_string_literal: true

module SignVerificationPasskeyActions
  extend ActiveSupport::Concern

  def new
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_get!
    return unless require_method_available!(:passkey)

    prepare_passkey_challenge!
    render_verification_passkey_page
  end

  def create
    return unless require_step_up_session!
    return if redirect_if_recent_verification_for_post!
    return unless require_method_available!(:passkey)

    if verify_passkey!
      consume_step_up_session!(method: :passkey)
    else
      record_failed_step_up_attempt!(:passkey)
      prepare_passkey_challenge!
      render_verification_passkey_page(status: :unprocessable_content)
    end
  end

  private

  # The status and the "show the challenge page again" shape are fixed; how that page is rendered
  # is not. A surface whose page is an Inertia component overrides this to render the component
  # with the same status instead of the ERB template.
  def render_verification_passkey_page(status: :ok)
    render :new, status: status
  end
end
