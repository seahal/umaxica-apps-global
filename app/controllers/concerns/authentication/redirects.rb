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
      value = safe_encoded_rt(redirect_parameter_value)
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
      rt_param = safe_encoded_rt(redirect_parameter_value).presence || session[session_key]
      session[session_key] = nil
      rt_param
    end

    # Retrieves redirect parameter without clearing session
    #
    # @param session_key [Symbol] The session key to retrieve from
    # @return [String, nil] The rt parameter value
    def peek_redirect_parameter(session_key = DEFAULT_RT_SESSION_KEY)
      safe_encoded_rt(redirect_parameter_value).presence || session[session_key]
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
        safe_path = safe_path_from_encoded_rt(rt_param, fallback: default_path)
        redirect_to_return_target_destination!(safe_path)
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
      destination = safe_path_from_encoded_rt(rt_param, fallback: nil)
      return redirect_to(default_path) if rt_param.blank?
      return render_invalid_return_target! if destination.blank?

      redirect_to_return_target_destination!(destination)
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

    def sign_in_welcome_path(rt: nil, id: nil)
      attrs = { ri: params[:ri] }
      safe_rt = safe_encoded_rt(rt)
      attrs[Auth::IoKeys::Params::RT] = safe_rt if safe_rt.present?
      _ = id

      if respond_to?(:sign_app_welcome_entry_path, true)
        sign_app_welcome_entry_path(**attrs)
      elsif respond_to?(:sign_org_welcome_entry_path, true)
        sign_org_welcome_entry_path(**attrs)
      elsif respond_to?(:sign_com_welcome_entry_path, true)
        sign_com_welcome_entry_path(**attrs)
      else
        path = "/welcome"
        query = attrs.compact.to_query
        query.present? ? "#{path}?#{query}" : path
      end
    end

    def sign_in_dashboard_path(rt: nil)
      _ = rt

      if respond_to?(:sign_app_dashboard_path, true)
        sign_app_dashboard_path(ri: params[:ri])
      elsif respond_to?(:sign_org_dashboard_path, true)
        sign_org_dashboard_path(ri: params[:ri])
      elsif respond_to?(:sign_com_dashboard_path, true)
        sign_com_dashboard_path(ri: params[:ri])
      else
        "/dashboard"
      end
    end

    def after_welcome_path
      sign_in_dashboard_path
    rescue StandardError
      default_after_login_path
    end

    alias after_dashboard_path after_welcome_path

    def safe_path_from_encoded_rt(rt_param, fallback:)
      return fallback if rt_param.blank?

      destination = verify_authentication_return_target_path(rt_param)
      safe_non_welcome_return_destination(destination, fallback: fallback)
    end

    def safe_encoded_rt(rt_param)
      return if rt_param.blank?

      token = rt_param.to_s
      verified_destination = verify_authentication_return_target_path(token)
      if safe_non_welcome_return_destination(verified_destination, fallback: nil).present?
        return token
      end

      issued_token = issue_authentication_return_target_token(token)
      issued_token if safe_path_from_encoded_rt(issued_token, fallback: nil).present?
    end

    def redirect_parameter_value
      params[Auth::IoKeys::Params::RT].presence
    end

    def safe_non_welcome_return_path(path, fallback:)
      safe_path = safe_internal_path(path)
      return fallback if safe_path.blank?
      return fallback if welcome_return_path?(safe_path)

      safe_path
    end

    alias safe_non_dashboard_return_path safe_non_welcome_return_path

    def safe_non_welcome_return_destination(destination, fallback:)
      return fallback if destination.blank?
      return fallback if welcome_return_path?(destination)

      uri = URI.parse(destination.to_s)
      return destination if uri.scheme.present? && uri.host.present?

      safe_non_welcome_return_path(destination, fallback: fallback)
    rescue URI::InvalidURIError
      fallback
    end

    def welcome_return_path?(path)
      candidate = URI.parse(path.to_s)
      welcome = URI.parse(sign_in_welcome_path)
      candidate.path == welcome.path || candidate.path == "/welcome" || candidate.path.start_with?("/welcomes/")
    rescue URI::InvalidURIError
      false
    end

    alias dashboard_return_path? welcome_return_path?

    def issue_authentication_return_target_token(return_to)
      ReturnTargetToken.issue(
        return_to: return_to,
        flow: authentication_return_target_flow,
        surface: authentication_return_target_surface,
        session_nonce: authentication_return_target_session_nonce,
        request: request,
      )
    rescue ReturnTargetToken::Invalid
      nil
    end

    def verify_authentication_return_target_path(token)
      ReturnTargetToken.verified_return_to(
        token,
        expected_flow: authentication_return_target_flow,
        expected_surface: authentication_return_target_surface,
        session_nonce: authentication_return_target_session_nonce,
        request: request,
      )
    end

    def redirect_to_return_target_destination!(destination)
      uri = URI.parse(destination.to_s)
      if uri.scheme.present? || uri.host.present?
        redirect_to(destination, allow_other_host: true)
      else
        redirect_to(destination, allow_other_host: false)
      end
    rescue URI::InvalidURIError
      redirect_to(default_after_login_path, allow_other_host: false)
    end

    def authentication_return_target_flow
      "authentication"
    end

    def authentication_return_target_surface
      surface_from_controller_name || Actor.tld.presence || "app"
    end

    def surface_from_controller_name
      case self.class.name
      when /::App::/ then "app"
      when /::Com::/ then "com"
      when /::Org::/ then "org"
      end
    end

    def authentication_return_target_session_nonce
      session[:authentication_return_target_nonce] ||= SecureRandom.urlsafe_base64(24)
    end

    def render_invalid_return_target!
      render(
        plain: I18n.t("errors.messages.invalid_request", default: "Invalid request"),
        status: :unprocessable_content,
      )
    end
  end
end
