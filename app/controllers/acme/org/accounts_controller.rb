# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class AccountsController < Acme::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      def index
      end
    end
  end
end
