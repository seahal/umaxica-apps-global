# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class SettingsController < Acme::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def show
        authorize!(current_visitor, to: :show?)
        render "acme/com/settings/show"
      end
    end
  end
end
