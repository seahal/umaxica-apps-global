# typed: false
# frozen_string_literal: true

module BasePreferenceViewRouteAliases
  extend ActiveSupport::Concern

  private

  def method_missing(name, ...)
    helper_name = name.to_s
    surface = base_preference_surface
    if helper_name.start_with?("auth_#{surface}_preference")
      return public_send(helper_name.sub(/\Aauth_/, "base_"), ...)
    end

    super
  end

  def respond_to_missing?(name, include_private = false)
    helper_name = name.to_s
    surface = base_preference_surface
    helper_name.start_with?("auth_#{surface}_preference") ||
      super
  end

  def base_preference_surface
    case self.class.name
    when /\ABase::Com::/ then "com"
    when /\ABase::Org::/ then "org"
    else
      "app"
    end
  end
end
