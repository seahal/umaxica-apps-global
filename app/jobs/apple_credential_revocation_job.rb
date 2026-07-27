# typed: false
# frozen_string_literal: true

class AppleCredentialRevocationJob < ApplicationJob
  queue_as :default

  def perform(public_id)
    request = ClientAppleCredentialRevocation.lock.find_by!(public_id: public_id)
    return if request.terminal?

    result = ExternalAuthentication::AppleCredentialRevocationAdapter.from_credentials.call(
      refresh_token: request.refresh_token,
    )

    if result.successful?
      request.complete!
      return
    end

    unless result.retryable?
      request.expire!(code: result.code.to_s)
      return
    end

    outcome = request.retry_or_expire!(code: result.code.to_s)
    return unless outcome == :retrying

    self.class.set(wait_until: request.next_retry_at).perform_later(request.public_id)
  end
end
