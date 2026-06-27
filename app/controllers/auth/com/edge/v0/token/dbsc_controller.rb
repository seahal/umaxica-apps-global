# typed: false
# frozen_string_literal: true

class Auth::Com::Edge::V0::Token::DbscController < ::Auth::Com::ApplicationController
  include SignEdgeV0JsonApi

  include SignDbscRegistrationEndpoint

  AUTHENTICATION_MODE = :deny_all

  declare_authentication_mode! :open
  before_action :ensure_json_request
  skip_before_action :set_region, raise: false
  skip_before_action :set_preferences_cookie
  skip_before_action :transparent_refresh_access_token

  private

  def dbsc_url
    sign_com_edge_v0_token_dbsc_url
  end
end
