# typed: false
# frozen_string_literal: true

class ExternalAuthenticationEntraRedirectUri
  CALLBACK_PATH = "/social/entra/callback"

  def self.call
    origin = Rails.configuration.x.boot_config.fetch(:hosts).auth_staff.to_s
    raise KeyError, "auth_staff origin is required" if origin.blank?

    "#{origin.chomp("/")}#{CALLBACK_PATH}"
  end
end
