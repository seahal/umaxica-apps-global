# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::Up::Guard::EmailsController < ::Sign::Com::Up::Guard::EmailsController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open
end
