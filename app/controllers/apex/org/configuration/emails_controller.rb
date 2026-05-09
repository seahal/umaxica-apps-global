# typed: false
# frozen_string_literal: true

module Apex
  module Org
    module Configuration
      class EmailsController < ApplicationController
        before_action :set_defaults, only: %i(new edit)

        def new
          # Renders new email configuration form
        end

        def edit
          # Renders edit email configuration form
        end

        def create
          head :ok
        end

        def update
          head :ok
        end

        private

        def set_defaults
          @current_region = params.expect(:ct)&.upcase || "US"
          @current_language = params.expect(:lx)&.upcase || I18n.locale.to_s.upcase.first(2)
          @current_timezone = params[:tz].presence || Time.zone&.name || "Etc/UTC"
        end
      end
    end
  end
end
