# typed: false
# frozen_string_literal: true

module Authentication
  module Redirects
    extend ActiveSupport::Concern
    include Common::Redirect

    DEFAULT_RT_SESSION_KEY = Auth::IoKeys::Session::DEFAULT_RT

    # Preserves the redirect parameter in session and returns it for immediate use
    #
    # @param session_key [Symbol] The session key to store rt parameter in
    # @return [String, nil] The rt parameter value if present
    def preserve_redirect_parameter(session_key = DEFAULT_RT_SESSION_KEY)
      value = redirect_parameter_value
      return if value.blank?

      session[session_key] = value
      value
    end

    # Retrieves and clears the redirect parameter from session
    # Falls back to params[:rt] if session is empty
    #
    # @param session_key [Symbol] The session key to retrieve from
    # @return [String, nil] The rt parameter value
    def retrieve_redirect_parameter(session_key = DEFAULT_RT_SESSION_KEY)
      rt_param = redirect_parameter_value.presence || session[session_key]
      session[session_key] = nil
      rt_param
    end

    # Retrieves redirect parameter without clearing session
    #
    # @param session_key [Symbol] The session key to retrieve from
    # @return [String, nil] The rt parameter value
    def peek_redirect_parameter(session_key = DEFAULT_RT_SESSION_KEY)
      redirect_parameter_value.presence || session[session_key]
    end

    # Builds redirect params hash with optional rt parameter.
    # Automatically includes rt from params or session if present.
    #
    # @param message_key [Symbol] Either :notice or :alert
    # @param message_value [String] The message text or translation key result
    # @param session_key [Symbol] The session key to check for rt parameter
    # @return [Hash] Redirect params hash
    def build_redirect_params(message_key, message_value, session_key = DEFAULT_RT_SESSION_KEY)
      redirect_params = { message_key => message_value }
      rt_value = peek_redirect_parameter(session_key)
      redirect_params[Auth::IoKeys::Params::RT] = rt_value if rt_value.present?
      redirect_params
    end

    # Builds redirect params hash with notice message
    #
    # @param message_value [String] The notice message
    # @param session_key [Symbol] The session key to check for rt parameter
    # @return [Hash] Redirect params with notice
    def build_notice_params(message_value, session_key = DEFAULT_RT_SESSION_KEY)
      build_redirect_params(:notice, message_value, session_key)
    end

    # Builds redirect params hash with alert message
    #
    # @param message_value [String] The alert message
    # @param session_key [Symbol] The session key to check for rt parameter
    # @return [Hash] Redirect params with alert
    def build_alert_params(message_value, session_key = DEFAULT_RT_SESSION_KEY)
      build_redirect_params(:alert, message_value, session_key)
    end

    # Performs redirect with rt parameter handling.
    # Either redirects to encoded rt URL or falls back to default path.
    #
    # @param default_path [String] Default path if no rt parameter
    # @param message_key [Symbol] Either :notice or :alert
    # @param message_value [String] Flash message value
    # @param session_key [Symbol] The session key for rt parameter
    def redirect_with_rt_handling(default_path, message_key, message_value,
                                  session_key = DEFAULT_RT_SESSION_KEY)
      rt_param = retrieve_redirect_parameter(session_key)

      if rt_param.present?
        flash[message_key] = message_value
        jump_to_generated_url(rt_param, fallback: default_path)
      else
        redirect_to(default_path, message_key => message_value)
      end
    end

    # Performs redirect with notice message and rt handling
    #
    # @param default_path [String] Default path if no rt parameter
    # @param message_value [String] Notice message value
    # @param session_key [Symbol] The session key for rt parameter
    def redirect_with_notice(default_path, message_value, session_key = DEFAULT_RT_SESSION_KEY)
      redirect_with_rt_handling(default_path, :notice, message_value, session_key)
    end

    # Performs redirect with alert message and rt handling
    #
    # @param default_path [String] Default path if no rt parameter
    # @param message_value [String] Alert message value
    # @param session_key [Symbol] The session key for rt parameter
    def redirect_with_alert(default_path, message_value, session_key = DEFAULT_RT_SESSION_KEY)
      redirect_with_rt_handling(default_path, :alert, message_value, session_key)
    end

    # Adds rt parameter to existing redirect params if present
    # Modifies the hash in place
    #
    # @param redirect_params [Hash] The redirect params hash to modify
    # @param session_key [Symbol] The session key to check for rt parameter
    # @return [Hash] The modified redirect_params hash
    def add_rt_to_params!(redirect_params, session_key = DEFAULT_RT_SESSION_KEY)
      rt_value = peek_redirect_parameter(session_key)
      redirect_params[Auth::IoKeys::Params::RT] = rt_value if rt_value.present?
      redirect_params
    end

    def safe_redirect_to_rt_or_default!(rt_param, default_path:)
      if rt_param.present?
        jump_to_generated_url(rt_param, fallback: default_path)
      else
        redirect_to(default_path)
      end
    end

    def sign_in_checkpoint_path(rt: nil)
      attrs = { ri: params[:ri] }
      safe_rt = safe_encoded_rt(rt)
      attrs[Auth::IoKeys::Params::RT] = safe_rt if safe_rt.present?

      if respond_to?(:sign_app_in_checkpoint_path, true)
        sign_app_in_checkpoint_path(**attrs)
      elsif respond_to?(:sign_org_in_checkpoint_path, true)
        sign_org_in_checkpoint_path(**attrs)
      elsif respond_to?(:sign_com_in_checkpoint_path, true)
        sign_com_in_checkpoint_path(**attrs)
      else
        "/sign/in/checkpoint"
      end
    end

    def sign_in_dashboard_path(rt: nil)
      attrs = { ri: params[:ri] }
      safe_rt = safe_encoded_rt(rt)
      attrs[Auth::IoKeys::Params::RT] = safe_rt if safe_rt.present?

      if respond_to?(:sign_app_dashboard_path, true)
        sign_app_dashboard_path(**attrs)
      elsif respond_to?(:sign_org_dashboard_path, true)
        sign_org_dashboard_path(**attrs)
      elsif respond_to?(:sign_com_dashboard_path, true)
        sign_com_dashboard_path(**attrs)
      else
        "/dashboard"
      end
    end

    def after_dashboard_path
      if respond_to?(:sign_app_configuration_path, true)
        sign_app_configuration_path(ri: params[:ri])
      elsif respond_to?(:sign_org_configuration_path, true)
        sign_org_configuration_path(ri: params[:ri])
      elsif respond_to?(:sign_com_configuration_path, true)
        sign_com_configuration_path(ri: params[:ri])
      else
        default_after_login_path
      end
    rescue StandardError
      default_after_login_path
    end

    # Resolve an `rt` redirect target. Accepts two shapes:
    #
    #   1. A Base64-url-encoded payload (the normal "from a URL" case).
    #      Decoded and checked with `safe_return_path`, which permits
    #      configured external hosts in addition to internal paths.
    #
    #   2. A raw internal path (e.g. `/after`) passed by trusted internal
    #      code that hasn't bothered to Base64-encode. We accept this
    #      only via `safe_internal_path`, which rejects anything with a
    #      scheme or host, so an external URL passed unencoded as
    #      `https://evil.example` still falls back. This is the safe
    #      reading of what was previously a pair of `safe_return_path`
    #      calls. See S-7: the earlier second branch passed the
    #      undecoded rt back through `safe_return_path`, which could
    #      surface external URLs whenever `allowed_return_hosts` was
    #      misconfigured.
    def safe_path_from_encoded_rt(rt_param, fallback:)
      return fallback if rt_param.blank?

      decoded_url = Base64.urlsafe_decode64(rt_param)
      decoded_path = safe_return_path(decoded_url)
      return decoded_path if decoded_path.present?

      safe_internal_path(rt_param) || fallback
    rescue ArgumentError, URI::InvalidURIError
      safe_internal_path(rt_param) || fallback
    end

    def safe_encoded_rt(rt_param)
      return if rt_param.blank?

      safe_path_from_encoded_rt(rt_param, fallback: nil).present? ? rt_param : nil
    end

    def redirect_parameter_value
      params[Auth::IoKeys::Params::RT].presence
    end
  end
end
