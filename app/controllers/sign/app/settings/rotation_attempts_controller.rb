# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Settings
      # Compatibility endpoint for secret credential rotation attempts.
      # sign/id does not own credential lifecycle; acme/www does. This endpoint exists only to keep
      # the POST .../rotation_attempt URL working by redirecting to the resource's acme settings page,
      # where the real rotation is authorized and performed.
      class RotationAttemptsController < ::Sign::App::ApplicationController
        include ::SignAcmeAuthorityRedirect

        AUTHENTICATION_MODE = :private
        before_action :authenticate_client!

        def create
          redirect_to_acme_authority!(canonical_resource_path, query: request.query_parameters)
        end

        private

        # Strip the trailing "/rotation_attempt" so the user lands on the resource's acme page.
        def canonical_resource_path = request.path.delete_suffix("/rotation_attempt")
      end
    end
  end
end
