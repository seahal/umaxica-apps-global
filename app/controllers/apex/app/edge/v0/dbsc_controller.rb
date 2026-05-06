# typed: false
# frozen_string_literal: true

module Apex
  module App
    module Edge
      module V0
        class DbscController < ApplicationController
          include ::Preference::WebCookieEndpoint
          include ::Preference::DbscRegistrationEndpoint

          skip_before_action :resolve_param_context, raise: false
          skip_before_action :set_region, raise: false

          skip_before_action :set_color_theme, raise: false
          skip_before_action :enforce_withdrawal_gate!, raise: false
          skip_before_action :transparent_refresh_access_token, raise: false
          skip_before_action :enforce_verification_if_required, raise: false

          private

          def dbsc_url
            apex_app_edge_v0_dbsc_url
          end
        end
      end
    end
  end
end
