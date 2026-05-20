# typed: false
# frozen_string_literal: true

module Apex
  module Dev
    class ApplicationController < ::ApplicationController
      include ::RateLimit
      include ::Session
      include ::ActorSupport
      include ::Finisher

      before_action :check_default_rate_limit
      before_action :set_current_context
      before_action :reset_flash
      after_action :purge_current

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
