# typed: false
# frozen_string_literal: true

module Sign
  module App
    class OpenidConfigurationsController < BareController
      AUTHENTICATION_MODE = :bare

      before_action :skip_metadata_session!

      def show
        render json: ::Oidc::DiscoveryDocument.for_resource_type("client")
      end

      private

      def skip_metadata_session!
        request.session_options[:skip] = true
      end
    end
  end
end
