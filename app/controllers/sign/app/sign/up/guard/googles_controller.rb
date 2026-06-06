# typed: false
# frozen_string_literal: true

class Sign::App::Sign::Up::Guard::GooglesController < ::Sign::App::Up::Guard::GooglesController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open
end
