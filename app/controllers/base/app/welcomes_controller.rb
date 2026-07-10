# typed: false
# frozen_string_literal: true

module Base
  module App
    class WelcomesController < Base::App::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!
      before_action :continue_welcome_sequence_without_content!

      def show
        render "base/shared/welcomes/show"
      end

      private

      def after_welcome_path
        base_app_dashboard_path(ri: params[:ri])
      end
    end
  end
end
