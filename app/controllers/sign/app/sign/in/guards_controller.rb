# typed: false
# frozen_string_literal: true

class Sign::App::Sign::In::GuardsController < ::Sign::App::In::GuardsController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open
end
