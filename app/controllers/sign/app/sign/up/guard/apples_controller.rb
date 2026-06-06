# typed: false
# frozen_string_literal: true

class Sign::App::Sign::Up::Guard::ApplesController < ::Sign::App::Up::Guard::ApplesController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open
end
