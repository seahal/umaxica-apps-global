# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Configuration
      class ConnectionsController < Sign::Org::ApplicationController
        include Sign::OidcConnectionsManagement

        AUTHENTICATION_MODE = :private
        before_action :authenticate_connection_actor!
        before_action :set_connection, only: %i(show destroy)
        # Object-level authorization (ActionPolicy) for the read paths. Restricts the listing to the
        # owning actor type on top of the owner-scoped query in the shared concern.
        before_action :authorize_connections!, only: %i(index show)
        before_action :authorize_connection_destroy!, only: :destroy
        helper_method :connection_status_label, :connection_scopes_text, :connection_last_used_text,
                      :connection_path_for, :connections_path, :configuration_path
        def index = super

        def show = super

        private

        def authenticate_connection_actor!
          authenticate_operator!
        end

        def authorize_connections!
          authorize!(OperatorOidcConnection, to: :index?)
        end

        def connections_scope
          current_operator.oidc_connections
        end

        def connection_path_for(connection)
          sign_org_configuration_connection_path(connection.public_id, ri: params[:ri])
        end

        def connections_path
          sign_org_configuration_connections_path(ri: params[:ri])
        end

        def configuration_path
          sign_org_configuration_path(ri: params[:ri])
        end
      end
    end
  end
end
