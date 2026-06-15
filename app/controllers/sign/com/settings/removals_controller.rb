# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Settings
      # Compatibility endpoint for credential removal (passkeys and secret credentials).
      # sign/id does not own credential lifecycle; acme/www does. This endpoint exists only to keep
      # the POST .../removal URL working by redirecting to the resource's acme settings page,
      # where the real removal is authorized and performed.
      class RemovalsController < ::Sign::Com::ApplicationController
        include ::SignAcmeAuthorityRedirect

        AUTHENTICATION_MODE = :private
        before_action :authenticate_visitor!

        def create
          redirect_to_acme_authority!(canonical_resource_path, query: request.query_parameters)
        end

        private

        def canonical_resource_path = request.path.delete_suffix("/removal")
      end
    end
  end
end
