# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module In
      class GuestController < Sign::Com::GuestController
        guest_only! status: :unauthorized, no_redirect: true
      end
    end
  end
end
