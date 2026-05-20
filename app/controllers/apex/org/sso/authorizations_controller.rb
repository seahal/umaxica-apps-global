# typed: false
# frozen_string_literal: true

module Apex
  module Org
    module Sso
      class AuthorizationsController < OpenController
        def show
          redirect_to(initiate_oidc_session!, allow_other_host: true)
        end
      end
    end
  end
end
