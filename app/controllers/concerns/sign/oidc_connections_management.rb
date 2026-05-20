# typed: false
# frozen_string_literal: true

module Sign
  module OidcConnectionsManagement
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_connection_actor!
      before_action :set_connection, only: %i(show destroy)

      helper_method :connection_status_label, :connection_scopes_text, :connection_last_used_text,
                    :connection_path_for, :connections_path, :configuration_path
    end

    def index
      @connections = connections_scope.recent_first
    end

    def show
      @active_token_count = @connection.active_tokens.count
    end

    def destroy
      return if require_step_up!(scope: "configuration_connection") == false

      Oidc::ConnectionRevoker.call(connection: @connection)
      redirect_to(
        connections_path,
        status: :see_other,
        notice: t("sign.configuration.connections.destroy.success"),
      )
    end

    private

    def set_connection
      @connection = connections_scope.find_by(public_id: params[:id])
      return if @connection

      head :not_found
      nil
    end

    def connection_status_label(connection)
      key = {
        "active" => "sign.configuration.connections.statuses.active",
        "revoked" => "sign.configuration.connections.statuses.revoked",
      }.fetch(connection.status)

      t(key)
    end

    def connection_scopes_text(connection)
      scopes = connection.scopes
      scopes.present? ? scopes.join(", ") : "-"
    end

    def connection_last_used_text(connection)
      return "-" if connection.last_used_at.blank?

      l(connection.last_used_at, format: :long)
    end
  end
end
