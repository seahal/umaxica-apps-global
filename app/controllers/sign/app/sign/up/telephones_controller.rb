# typed: false
# frozen_string_literal: true

class Sign::App::Sign::Up::TelephonesController < ::Sign::App::Up::TelephonesController
  AUTHENTICATION_MODE = :guest
  declare_authentication_mode! :guest, status: :unauthorized,
                                       message: I18n.t("errors.messages.already_authenticated"),
                                       no_redirect: true

  def self.local_prefixes = ["sign/app/up/telephones"] + super
end
