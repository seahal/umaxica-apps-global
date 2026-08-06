# typed: false
# frozen_string_literal: true

# Shared entry point for the app-surface social ceremony controllers
# (Auth::App::Social::SessionsController and RegistrationsController).
#
# The ceremony is POST only. The press of an in-application provider button
# supplies the CSRF token the OmniAuth request phase requires, and the handoff is
# a 307 so that same POST, method and body intact, reaches the request phase
# (OmniAuth.config.allowed_request_methods = [:post]).
#
# There is no GET entry on purpose: a GET carries no token, so a link that
# started a ceremony would be login CSRF (CVE-2015-9284). People choose their
# provider on the sign-in or sign-up page.
#
# The OmniAuth callbacks are handled by Auth::App::Omniauth::OmniauthCallbacksController.
module SocialCeremonyEntry
  extend ActiveSupport::Concern

  SUPPORTED_PROVIDERS = %w(google apple).freeze
  SOCIAL_LINK_SCOPE = SocialAuth::SOCIAL_LINK_SCOPE

  included do
    include SocialAuth

    rescue_from SocialAuth::BaseError, with: :handle_social_auth_error
    rescue_from ActiveRecord::RecordNotUnique, with: :handle_record_not_unique

    before_action :require_social_link_step_up!, only: :create
  end

  private

  # Prepares the ceremony, then hands the request on with a 307.
  def handoff_social_ceremony!
    return unless prepare_social_ceremony!

    redirect_to(
      omniauth_authorize_path(params[:provider]),
      status: :temporary_redirect,
    )
  rescue SocialAuth::BaseError => e
    handle_social_auth_error(e)
  end

  # Params:
  #   - provider: "google" or "apple" (route default)
  #   - intent: "login", "link", or "step_up" (default: "login")
  #     "login" is the internal continue flow: existing identities sign in,
  #     missing identities create a new account.
  #
  # @return [Boolean] false when the request was redirected instead.
  def prepare_social_ceremony!
    provider = params[:provider]
    intent = params[:intent] || "login"

    unless SUPPORTED_PROVIDERS.include?(provider)
      redirect_to(auth_app_sign_in_path)
      return false
    end

    # Prepare session with intent context (OmniAuth manages OAuth state)
    state = prepare_social_auth_intent!(
      intent,
      provider: provider,
      pt: nil,
      entry: social_auth_entry,
      ri: params[:ri].presence,
    )
    if params[:social_ceremony_grant].present?
      store_social_ceremony_grant!(params[:social_ceremony_grant])
    elsif intent.to_s == "login"
      issuance = IdentitySocialCeremonyGrantIssuer.issue!(
        surface: "app",
        actor_ref: social_login_actor_ref,
        session_ref: state,
        operation: "login",
        provider: provider,
        resource_ref: social_auth_entry,
        return_to: path_from_signed_pt(signed_pt_token(resolved_path_or_navigation_target)),
      )
      store_social_ceremony_grant!(issuance.grant)
    end
    issue_sign_up_flow!(provider) if social_auth_entry == "sign_up"

    true
  end

  def social_auth_entry
    return "sign_up" if %w(sign_up auth_up).include?(request.parameters["entry"].to_s)

    referer_path = URI.parse(request.referer.to_s).path
    return "sign_up" if referer_path == auth_app_sign_up_path

    "sign_in"
  rescue URI::InvalidURIError
    "sign_in"
  end

  def issue_sign_up_flow!(provider)
    cycle =
      AppTicketRecord.connected_to(role: :writing) do
        ClientSignUpFlowStatus.ensure_defaults!
        ClientSignUpFlow.create!(
          principal_id: nil,
          status_id: ClientSignUpFlowStatus::STARTED,
          step: "start",
          nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: Time.current,
          expires_at: ClientSignUpFlow.default_ttl.from_now,
          entry_method: social_entry_method(provider),
          social_provider: social_entry_method(provider),
          return_to: resolved_path_or_navigation_target,
        )
      end
    result =
      AppTicketRecord.connected_to(role: :writing) do
        SignUpStateMachine.call(
          ticket: cycle,
          event: :start_social_callback,
          actor_context: Actor.authn,
        )
      end
    raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless result.status == :advanced

    sign_up_flow_locator.issue!(cycle)
    session[:auth_app_up_sequence_id] = cycle.public_id
  end

  def social_login_actor_ref
    "anonymous"
  end

  def social_entry_method(provider)
    SocialIdentifiable.normalize_provider(provider)
  end

  def sign_up_flow_locator
    SignUpCycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow)
  end

  # A link intent arriving from settings has to be recently step-up verified.
  def require_social_link_step_up!
    return true unless params[:intent].to_s == "link"
    return true unless SUPPORTED_PROVIDERS.include?(params[:provider].to_s)
    return true unless logged_in? && current_resource.present?
    return true if step_up_satisfied?(scope: SOCIAL_LINK_SCOPE)

    redirect_to(
      actor_verification_path(
        scope: SOCIAL_LINK_SCOPE,
        pt: encoded_relative_pt(social_link_settings_path(params[:provider])),
        ri: params[:ri],
      ),
      status: :see_other,
    )
    false
  end

  def social_link_settings_path(provider)
    case SocialIdentifiable.normalize_provider(provider)
    when "apple"
      auth_app_settings_apple_path(ri: params[:ri])
    else
      auth_app_settings_google_path(ri: params[:ri])
    end
  end
end
