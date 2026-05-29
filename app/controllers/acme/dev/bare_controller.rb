# typed: false
# frozen_string_literal: true

module Acme
  module Dev
    class BareController < ApplicationController
      include ::RateLimit

      AUTHENTICATION_MODE = :bare

      allow_browser versions: :modern

      before_action :check_default_rate_limit

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
