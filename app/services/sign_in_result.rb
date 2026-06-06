# typed: false
# frozen_string_literal: true

TERMINAL_HTTP_STATUSES = {
  session_limit_hard_reject: :forbidden,
  guardrail_blocked: :forbidden,
  login_forbidden: :forbidden,
  credential_failed: :unauthorized,
  invalid_request: :bad_request,
}.freeze

SignInResult =
  Data.define(
    :status,
    :actor,
    :token,
    :sequence_id,
    :redirect_to,
    :response_status,
    :message,
  ) do
    def self.from_session_result(result, actor: nil, sequence_id: nil, session_management_path: nil)
      data = result.to_h.symbolize_keys
      status = normalized_status(data)

      new(
        status: status,
        actor: actor,
        token: token_payload(data),
        sequence_id: sequence_id,
        redirect_to: redirect_target(data, status: status, session_management_path: session_management_path),
        response_status: response_status(data, status: status),
        message: data[:message] || data[:error],
      )
    end

    def success?
      status == :success
    end

    def terminal?
      TERMINAL_HTTP_STATUSES.key?(status)
    end

    def session_limit_pending?
      status == :session_limit_pending
    end

    def mfa_required?
      status == :mfa_required
    end

    def self.normalized_status(data)
      status = data[:status]&.to_sym
      return :session_limit_pending if data[:restricted] || data[:session_management_required]
      return :session_limit_pending if status == :session_limit_exceeded
      return status if status.present?

      :invalid_request
    end
    private_class_method :normalized_status

    def self.token_payload(data)
      return data[:tokens] if data[:tokens].present?
      return data if data[:access_token].present?

      nil
    end
    private_class_method :token_payload

    def self.redirect_target(data, status:, session_management_path:)
      return data[:redirect_path] if data[:redirect_path].present?
      return session_management_path if status == :session_limit_pending

      nil
    end
    private_class_method :redirect_target

    def self.response_status(data, status:)
      return data[:http_status] if data[:http_status].present?
      return :found if %i(success mfa_required session_limit_pending).include?(status)

      TERMINAL_HTTP_STATUSES.fetch(status, :bad_request)
    end
    private_class_method :response_status
  end
