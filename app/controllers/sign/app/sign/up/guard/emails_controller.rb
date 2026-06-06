# typed: false
# frozen_string_literal: true

class Sign::App::Sign::Up::Guard::EmailsController < ::Sign::App::Up::Guard::EmailsController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open
end
