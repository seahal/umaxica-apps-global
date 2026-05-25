# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Verification
      class PasskeysController < Sign::Com::Verification::BaseController
        AUTHENTICATION_MODE = :private

        include Sign::VerificationPasskeyActions
      end
    end
  end
end
