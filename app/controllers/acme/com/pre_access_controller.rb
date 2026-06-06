# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class PreAccessController < Acme::Com::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!
    end
  end
end
