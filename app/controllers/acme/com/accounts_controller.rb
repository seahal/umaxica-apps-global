# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class AccountsController < Acme::Com::ApplicationController
      AUTHENTICATION_MODE = :private

      def index
      end
    end
  end
end
