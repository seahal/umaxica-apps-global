# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class PreferencesBaseController < ::Sign::Org::ApplicationController
      include ::SignAcmeAuthorityRedirect

      AUTHENTICATION_MODE = :open

      layout "sign/org/application"

      prepend_before_action :redirect_localhost_preference_authority!
      before_action :authorize_preference_write!, if: :preference_write_request?

      private

      def set_current_actor
        refresh_preference_token_from_db_for_edit_entry! if preference_edit_entry_request?
        super
      end

      def set_preferences_cookie
        return if request.host.end_with?(".localhost")

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

      def redirect_localhost_preference_authority!
        return if request.ssl?

        redirect_to_acme_authority!(request.path, query: request.query_parameters)
      end
    end
  end
end
