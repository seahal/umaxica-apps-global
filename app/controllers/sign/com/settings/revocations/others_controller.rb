# typed: false
# frozen_string_literal: true

class Sign::Com::Settings::Revocations::OthersController < ::Sign::Com::ApplicationController
  include ::SignAcmeAuthorityRedirect

  AUTHENTICATION_MODE = :private

  before_action :authenticate_visitor!

  def create = redirect_to_acme_sessions!

  private

  def redirect_to_acme_sessions!
    redirect_to_acme_authority!("/sign/settings/sessions")
  end
end
