# typed: false
# frozen_string_literal: true

# Resolves the Publishing::Edition for a request from its audience/surface
# (determined by the controller's host-constrained namespace, not by a query
# parameter) and its resolved locale. See adr/publishing-db-content-authority.md.
class PublishingEditionResolver < ApplicationService
  def initialize(audience:, surface:, locale:)
    super()
    @audience = audience.to_s
    @surface = surface.to_s
    @locale = locale.to_s
  end

  def call
    Publishing::Edition.find_by(audience: audience, surface: surface, locale: locale)
  end

  private

  attr_reader :audience, :surface, :locale
end
