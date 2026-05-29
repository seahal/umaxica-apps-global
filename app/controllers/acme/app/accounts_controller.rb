# typed: false
# frozen_string_literal: true

module Acme
  module App
    class AccountsController < PrivateController
      AUTHENTICATION_MODE = :private

      def index
      end
    end
  end
end
