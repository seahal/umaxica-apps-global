# typed: false
# frozen_string_literal: true

class OrgOperatorLifecycleInvitationIssuer
  def self.call(request:, actor:)
    new(request: request, actor: actor).call
  end

  def initialize(request:, actor:)
    @request = request
    @actor = actor
  end

  def call
    OrgInvitationService.create(
      organization_id: request.organization_id,
      email: request.target_email,
      invited_by: actor,
      role_id: request.role_id,
    )
  end

  private

  attr_reader :request, :actor
end
