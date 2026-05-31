# typed: false
# frozen_string_literal: true

module Acme
  module Dev
    # Intentionally bypasses ApplicationController and its app-wide callbacks.
    # Do not normalize this inheritance; bare endpoints own only the callbacks declared here.
    class BareController < ActionController::Base
      include ::RateLimit

      AUTHENTICATION_MODE = :bare

      allow_browser versions: :modern

      before_action :check_default_rate_limit

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
