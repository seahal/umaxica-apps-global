# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class PreferencesBaseController < Acme::Org::ApplicationController
      include ::Acme::PreferenceViewRouteAliases

      AUTHENTICATION_MODE = :open

      layout "sign/org/application"

      before_action :authorize_preference_write!, if: :preference_write_request?

      private

      def set_current_actor
        refresh_preference_token_from_db_for_edit_entry! if preference_edit_entry_request?
        super
      end

      def preference_write_request?
        !request.get? && !request.head?
      end

      def preference_edit_entry_request?
        (request.get? || request.head?) && request.format.html? && action_name == "edit"
      end

      def authorize_preference_write!
        authorize!(@preferences || preference_class, to: :update?)
      end
    end
  end
end
