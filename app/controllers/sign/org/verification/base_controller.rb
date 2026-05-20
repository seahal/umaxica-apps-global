# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Verification
      class BaseController < Sign::Org::PrivateController
        include Sign::OrgVerificationBase

        skip_before_action :enforce_verification_if_required, raise: false
      end
    end
  end
end
