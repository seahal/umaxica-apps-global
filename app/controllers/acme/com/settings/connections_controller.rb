# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Settings
      class ConnectionsController < Acme::Com::ApplicationController
        include AcmeSettingsOidcConnectionsManagement

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_visitor!
        before_action :set_connection, only: %i(show destroy)
        before_action :authorize_connections!, only: %i(index show)
        before_action :authorize_connection_destroy!, only: :destroy
        helper_method :connection_status_label, :connection_scopes_text, :connection_last_used_text,
                      :connection_path_for, :connections_path, :settings_path

        def index
          super
          render "acme/com/settings/connections/index" unless performed?
        end

        def show
          super
          render "acme/com/settings/connections/show" unless performed?
        end

        def destroy = super

        private

        def authorize_connections!
          authorize!(VisitorOidcConnection, to: :index?)
        end

        def connections_scope
          current_visitor.oidc_connections
        end

        def connection_path_for(connection)
          acme_com_settings_connection_path(connection.public_id, ri: params[:ri])
        end

        def connections_path
          acme_com_settings_connections_path(ri: params[:ri])
        end

        def settings_path
          acme_com_settings_path(ri: params[:ri])
        end
      end
    end
  end
end
