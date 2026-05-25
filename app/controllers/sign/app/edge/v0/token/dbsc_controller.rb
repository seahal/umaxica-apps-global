# typed: false
# frozen_string_literal: true

class Sign::App::Edge::V0::Token::DbscController < Sign::App::ApplicationController
  AUTHENTICATION_MODE = :deny_all

  include Sign::EdgeV0JsonApi
  include Sign::DbscRegistrationEndpoint

  declare_authentication_mode! :open
  before_action :ensure_json_request
  skip_before_action :set_region, raise: false
  skip_before_action :set_preferences_cookie
  skip_before_action :transparent_refresh_access_token

  private

  def dbsc_url
    sign_app_edge_v0_token_dbsc_url
  end
end
