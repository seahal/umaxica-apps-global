# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Settings
      # Compatibility endpoint for secret credential rotation.
      # sign/id owns credential lifecycle. This endpoint keeps the POST .../rotation URL working
      # by redirecting to the resource's canonical sign settings page.
      class RotationsController < ::Auth::Com::ApplicationController
        include ::SignAuthorityRedirect

        AUTHENTICATION_MODE = :private
        before_action :authenticate_visitor!

        def create
          redirect_to_sign_authority!(canonical_resource_path, query: request.query_parameters)
        end

        private

        def canonical_resource_path
          request.path.delete_suffix("/rotation")
        end
      end
    end
  end
end
