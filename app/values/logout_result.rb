# typed: false
# frozen_string_literal: true

LogoutResult =
  Data.define(:status, :token, :revoked_tokens, :redirect_to, :response_status, :message) do
    def self.success(token: nil, revoked_tokens: [], redirect_to: nil, message: nil)
      new(
        status: :success,
        token: token,
        revoked_tokens: revoked_tokens,
        redirect_to: redirect_to,
        response_status: :ok,
        message: message,
      )
    end

    def success?
      status == :success
    end
  end
