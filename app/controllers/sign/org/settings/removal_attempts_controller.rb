# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Settings
      # Compatibility endpoint for credential removal attempts (passkeys and secret credentials).
      # sign/id does not own credential lifecycle; acme/www does. This endpoint exists only to keep
      # the POST .../removal_attempt URL working by redirecting to the resource's acme settings page,
      # where the real removal is authorized and performed. Mirrors the prior destroy compatibility
      # redirect that this RESTful "attempt" resource replaced.
      class RemovalAttemptsController < ::Sign::Org::ApplicationController
        include ::SignAcmeAuthorityRedirect

        AUTHENTICATION_MODE = :private
        before_action :authenticate_client!

        def create
          redirect_to_acme_authority!(canonical_resource_path, query: request.query_parameters)
        end

        private

        # Strip the trailing "/removal_attempt" so the user lands on the resource's acme page.
        def canonical_resource_path = request.path.delete_suffix("/removal_attempt")
      end
    end
  end
end
