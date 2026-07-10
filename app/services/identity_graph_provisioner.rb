# typed: false
# frozen_string_literal: true

class IdentityGraphProvisioner
  def self.call!(surface:, principal:)
    new(surface: surface, principal: principal).call!
  end

  def initialize(surface:, principal:)
    @surface = surface
    @principal = principal
  end

  def call!
    BaseSelectorBootstrapAuthority.call(surface: surface, principal: principal)
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "identity.graph_provisioning.failed",
        surface: surface,
        principal_class: principal.class.name,
        principal_id: principal.id,
        error_class: e.class.name,
        error_message: e.message,
      ),
    )
    raise
  end

  private

  attr_reader :surface, :principal
end
