# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Configuration
      class ConnectionsController < Sign::Com::ApplicationController
        include Sign::OidcConnectionsManagement

        AUTHENTICATION_MODE = :private

        private

        def authenticate_connection_actor!
          authenticate_visitor!
        end

        def connections_scope
          current_visitor.oidc_connections
        end

        def connection_path_for(connection)
          sign_com_configuration_connection_path(connection.public_id, ri: params[:ri])
        end

        def connections_path
          sign_com_configuration_connections_path(ri: params[:ri])
        end

        def configuration_path
          sign_com_configuration_path(ri: params[:ri])
        end
      end
    end
  end
end
