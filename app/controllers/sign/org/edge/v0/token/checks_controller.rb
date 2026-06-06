# typed: false
# frozen_string_literal: true

class Sign::Org::Edge::V0::Token::ChecksController < ::Sign::Org::ApplicationController
  include SignEdgeV0JsonApi

  AUTHENTICATION_MODE = :deny_all

  declare_authentication_mode! :open
  before_action :ensure_json_request
  skip_before_action :set_region, raise: false
  skip_before_action :set_preferences_cookie
  skip_before_action :transparent_refresh_access_token
  skip_before_action :set_current_actor, raise: false

  def show
    response.set_header("Cache-Control", "no-store")

    authenticated = logged_in? && current_resource.active?
    issue_dbsc_registration_header_for(current_session) if authenticated
    body =
      if authenticated
        {
          authenticated: true,
          type: resource_type,
          id: current_resource.id,
          sid: current_session_public_id,
          dbsc: dbsc_payload_for(current_session),
        }
      else
        { authenticated: false }
      end

    render json: body, status: authenticated ? :ok : :unauthorized
  end
end
