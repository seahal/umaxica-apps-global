# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Edge
      module V0
        class DbscController < Acme::Org::ApplicationController
          include ::Preference::WebCookieEndpoint

          include ::Preference::DbscRegistrationEndpoint

          AUTHENTICATION_MODE = :deny_all

          skip_before_action :resolve_param_context, raise: false
          skip_before_action :set_region, raise: false

          skip_before_action :set_color_theme, raise: false
          skip_before_action :enforce_withdrawal_gate!, raise: false
          skip_before_action :transparent_refresh_access_token
          skip_before_action :enforce_verification_if_required

          private

          def dbsc_url
            acme_org_edge_v0_dbsc_url
          end
        end
      end
    end
  end
end
