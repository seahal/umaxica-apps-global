# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class WelcomesController < Acme::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!
      before_action :continue_welcome_sequence_without_content!

      def show
        render "acme/shared/welcomes/show"
      end

      private

      def after_welcome_path
        acme_com_dashboard_path(ri: params[:ri])
      end
    end
  end
end
