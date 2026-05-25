# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Configuration
      class ConnectionsController < PrivateController
        AUTHENTICATION_MODE = :private

        include Sign::OidcConnectionsManagement

        private

        def authenticate_connection_actor!
          authenticate_client!
        end

        def connections_scope
          current_client.oidc_connections
        end

        def connection_path_for(connection)
          sign_app_configuration_connection_path(connection.public_id, ri: params[:ri])
        end

        def connections_path
          sign_app_configuration_connections_path(ri: params[:ri])
        end

        def configuration_path
          sign_app_configuration_path(ri: params[:ri])
        end
      end
    end
  end
end
