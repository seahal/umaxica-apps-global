# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module In
      class GuestController < Sign::Org::GuestController
        guest_only! status: :unauthorized, no_redirect: true
      end
    end
  end
end
