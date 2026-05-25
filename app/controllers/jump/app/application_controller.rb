# typed: false
# frozen_string_literal: true

module Jump
  module App
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::ActorSupport

      allow_browser versions: :modern

      before_action :check_default_rate_limit
      before_action :set_current_context
      before_action :set_current_actor
      prepend_around_action :with_actor_lifecycle

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
