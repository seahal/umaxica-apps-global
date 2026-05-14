# typed: false
# frozen_string_literal: true

module Sign
  module Net
    class ApplicationController < Sign::PublicController
      include ::RateLimit
      include ::Session
      include ::CurrentSupport
      include ::Finisher

      helper Sign::Net::ApplicationHelper

      before_action :check_default_rate_limit
      before_action :reset_flash
      after_action :purge_current

      public_strict!
    end
  end
end
