# typed: false
# frozen_string_literal: true

module Acme
  module Selector
    def self.config_for(surface)
      SurfaceConfig::CONFIGS.fetch(surface.to_sym)
    end
  end
end
