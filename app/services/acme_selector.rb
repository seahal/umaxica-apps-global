# typed: false
# frozen_string_literal: true

module AcmeSelector
  def self.config_for(surface)
    AcmeSelectorSurfaceConfig::CONFIGS.fetch(surface.to_sym)
  end
end
