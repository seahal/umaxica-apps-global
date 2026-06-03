# typed: false
# frozen_string_literal: true

module Acme
  module PreferenceViewRouteAliases
    extend ActiveSupport::Concern

    private

    def method_missing(name, ...)
      helper_name = name.to_s
      surface = acme_preference_surface
      if helper_name.start_with?("sign_#{surface}_preference")
        return public_send(helper_name.sub(/\Asign_/, "acme_"), ...)
      end

      super
    end

    def respond_to_missing?(name, include_private = false)
      helper_name = name.to_s
      surface = acme_preference_surface
      helper_name.start_with?("sign_#{surface}_preference") ||
        super
    end

    def acme_preference_surface
      case self.class.name
      when /\AAcme::Com::/ then "com"
      when /\AAcme::Org::/ then "org"
      else
        "app"
      end
    end
  end
end
