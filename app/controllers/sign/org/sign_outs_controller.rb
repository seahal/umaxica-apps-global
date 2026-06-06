# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class SignOutsController < ::Sign::RedirectOnlyController
      AUTHENTICATION_MODE = :private
      def show = redirect_to_acme_sign_out!

      def edit = redirect_to_acme_sign_out!

      def create = redirect_to_acme_sign_out!

      def destroy = redirect_to_acme_sign_out!

      private

      # sign/id is redirect-only here. acme/www owns session mutation.
      def redirect_to_acme_sign_out!
        redirect_to_acme_authority!("/sign/out")
      end
    end
  end
end
