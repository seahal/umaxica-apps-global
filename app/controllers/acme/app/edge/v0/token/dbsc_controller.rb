# typed: false
# frozen_string_literal: true

class Acme::App::Edge::V0::Token::DbscController < Acme::App::ApplicationController
  include Sign::EdgeV0JsonApi
  include Sign::DbscRegistrationEndpoint

  AUTHENTICATION_MODE = :deny_all

  declare_authentication_mode! :open
  before_action :ensure_json_request

  private

  def dbsc_url
    acme_app_edge_v0_token_dbsc_url
  end
end
