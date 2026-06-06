# typed: false
# frozen_string_literal: true

module AcmeSettingsOidcConnectionsManagement
  extend ActiveSupport::Concern

  def index
    @connections = connections_scope.recent_first
  end

  def show
    @active_token_count = @connection.active_tokens.count
  end

  def destroy
    return if require_step_up!(scope: "settings_connection") == false

    OidcConnectionRevoker.call(connection: @connection)
    redirect_to(
      connections_path,
      status: :see_other,
      notice: t("sign.settings.connections.destroy.success"),
    )
  end

  private

  def authorize_connection_destroy!
    authorize!(@connection, to: :destroy?)
  end

  def set_connection
    @connection = connections_scope.find_by(public_id: params[:id])
    return if @connection

    head :not_found
    nil
  end

  def connection_status_label(connection)
    key = {
      "active" => "sign.settings.connections.statuses.active",
      "revoked" => "sign.settings.connections.statuses.revoked",
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
