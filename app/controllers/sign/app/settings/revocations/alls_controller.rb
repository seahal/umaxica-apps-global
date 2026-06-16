# typed: false
# frozen_string_literal: true

class Sign::App::Settings::Revocations::AllsController < ::Sign::App::ApplicationController
  include ::SignAcmeAuthorityRedirect

  AUTHENTICATION_MODE = :private

  before_action :authenticate_client!

  def create = redirect_to_acme_sessions!

  private

  def redirect_to_acme_sessions!
    redirect_to_acme_authority!("/settings/sessions")
  end
end
