# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Verification
      class PasskeysController < ::Auth::Com::Verification::BaseController
        include SignVerificationPasskeyActions

        AUTHENTICATION_MODE = :private
      end
    end
  end
end
