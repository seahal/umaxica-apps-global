# typed: false
# frozen_string_literal: true

module Apex
  module Com
    class BareController < ActionController::Base
      AUTHENTICATION_MODE = :bare

      include ::RateLimit

      allow_browser versions: :modern

      before_action :check_default_rate_limit

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
