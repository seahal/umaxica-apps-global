# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::In::EmailsController < ::Sign::Com::In::EmailsController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode!(
    :guest,
    status: :bad_request,
    message: I18n.t("sign.app.authentication.email.new.you_have_already_logged_in"),
    no_redirect: true,
  )

  def self.local_prefixes = ["sign/com/in/emails"] + super
end
