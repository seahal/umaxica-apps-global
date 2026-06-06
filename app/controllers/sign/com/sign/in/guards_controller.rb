# typed: false
# frozen_string_literal: true

class Sign::Com::Sign::In::GuardsController < ::Sign::Com::In::GuardsController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open
end
