# typed: false
# frozen_string_literal: true

class Sign::Org::Sign::In::GuardsController < ::Sign::Org::In::GuardsController
  AUTHENTICATION_MODE = :open
  declare_authentication_mode! :open
end
