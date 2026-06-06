# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class PreAccessController < Acme::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!
    end
  end
end
