# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::EmailsController < ::Sign::App::In::EmailsController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode!(
    :guest,
    status: :bad_request,
    message: I18n.t("sign.app.authentication.email.new.you_have_already_logged_in"),
    no_redirect: true,
  )

  def self.local_prefixes = ["sign/app/in/emails"] + super
end
