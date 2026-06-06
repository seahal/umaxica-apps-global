# typed: false
# frozen_string_literal: true

class Sign::App::Sign::Up::Guard::TelephonesController < ::Sign::App::Up::Guard::TelephonesController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open
end
