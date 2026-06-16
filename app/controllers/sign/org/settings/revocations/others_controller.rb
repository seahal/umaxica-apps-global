# typed: false
# frozen_string_literal: true

class Sign::Org::Settings::Revocations::OthersController < ::Sign::Org::ApplicationController
  include ::SignAcmeAuthorityRedirect

  AUTHENTICATION_MODE = :private

  before_action :authenticate_operator!

  def create = redirect_to_acme_sessions!

  private

  def redirect_to_acme_sessions!
    redirect_to_acme_authority!("/settings/sessions")
  end
end
