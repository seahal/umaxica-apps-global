# typed: false
# frozen_string_literal: true

module Acme
  module Dev
    class ApplicationController < ActionController::Base
      include ::RateLimit

      include ::Session

      include ::ActorSupport

      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      before_action :check_default_rate_limit
      before_action :set_current_context
      before_action :reset_flash
      prepend_around_action :with_actor_lifecycle

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
