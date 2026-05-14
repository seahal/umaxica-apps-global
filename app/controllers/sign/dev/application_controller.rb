# typed: false
# frozen_string_literal: true

module Sign
  module Dev
    class ApplicationController < Sign::PublicController
      include ::RateLimit
      include ::Session
      include ::CurrentSupport
      include ::Finisher

      helper Sign::Dev::ApplicationHelper

      before_action :check_default_rate_limit
      before_action :reset_flash
      after_action :purge_current

      public_strict!
    end
  end
end
