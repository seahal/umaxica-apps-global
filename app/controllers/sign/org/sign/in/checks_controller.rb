# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Sign
      module In
        class ChecksController < ::Sign::Org::ApplicationController
          include SignOrgInCheckControllerSupport
        end
      end
    end
  end
end
