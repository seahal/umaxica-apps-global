# typed: false
# frozen_string_literal: true

module Apex
  module App
    module Configuration
      class EmailsController < ApplicationController
        before_action :set_defaults, only: %i(new edit)

        def new
          # New email configuration form
        end

        def edit
          # Edit email configuration form
        end

        def create
          # Create email configuration
          head :ok
        end

        def update
          # Update email configuration
          head :ok
        end

        private

        def set_defaults
          # View expects @current_region, @current_language and @current_timezone
          # Prioritize URL parameters with i18n fallbacks
          @current_region = params.expect(:ct)&.upcase || "US"
          @current_language = params.expect(:lx)&.upcase || I18n.locale.to_s.upcase.first(2)
          @current_timezone = params[:tz].presence || Time.zone&.name || "Etc/UTC"
        end
      end
    end
  end
end
