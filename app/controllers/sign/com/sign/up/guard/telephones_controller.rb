# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::Up::Guard::TelephonesController < ::Sign::Com::Up::Guard::TelephonesController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open
end
