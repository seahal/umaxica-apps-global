# typed: false
# frozen_string_literal: true

module Apex
  class PublicController < ApplicationController
    include ::RateLimit

    allow_browser versions: :modern

    before_action :check_default_rate_limit

    protect_from_forgery using: :header_or_legacy_token, with: :exception

    def self.public_strict!(*)
    end
  end
end
