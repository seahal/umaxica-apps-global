# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Verification
      class PasskeysController < Sign::Com::Verification::BaseController
        include Sign::VerificationPasskeyActions
      end
    end
  end
end
