# typed: false
# frozen_string_literal: true

class Sign::Com::Edge::V0::Token::DbscController < Sign::Com::ApplicationController
  include Sign::EdgeV0JsonApi
  include Sign::DbscRegistrationEndpoint

  public_strict!
  skip_before_action :set_preferences_cookie
  skip_before_action :transparent_refresh_access_token

  private

  def dbsc_url
    sign_com_edge_v0_token_dbsc_url
  end
end
