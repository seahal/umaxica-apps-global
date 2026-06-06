# typed: false
# frozen_string_literal: true

module Acme
  module App
    class PreAccessController < Acme::App::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!
    end
  end
end
