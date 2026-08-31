# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyFreshnessRevoker
  def self.call!(token)
    new(token).call!
  end

  def initialize(token)
    @token = token
  end

  def call!
    token.update!(revocation_attributes)
  end

  private

  attr_reader :token

  def revocation_attributes
    attributes = {
      last_step_up_at: nil,
      last_step_up_scope: nil,
    }
    attributes[:last_step_up_aal] = nil if token_has_attribute?(:last_step_up_aal)
    attributes[:last_step_up_method] = nil if token_has_attribute?(:last_step_up_method)
    attributes[:last_step_up_purpose] = nil if token_has_attribute?(:last_step_up_purpose)
    attributes[:last_step_up_audience] = nil if token_has_attribute?(:last_step_up_audience)
    attributes[:last_step_up_session_public_id] = nil if token_has_attribute?(:last_step_up_session_public_id)
    attributes
  end

  def token_has_attribute?(attribute)
    token.respond_to?(:has_attribute?) && token.has_attribute?(attribute.to_s)
  end
end
