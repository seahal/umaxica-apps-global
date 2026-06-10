# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Dev
      module R18
        # TODO: Remove these temporary R18 smoke-test routes after R18 gate rollout is verified.
        class PrivateSmokesController < Acme::App::ApplicationController
          include ::R18Gate

          AUTHENTICATION_MODE = :open
          class_attribute :r18_required_actions, default: Set.new # rubocop:disable ThreadSafety/ClassAndModuleAttributes
          prepend_before_action :require_dev_private_authentication!
          before_action :require_r18_viewing!

          def show
            render plain: "private r18 ok"
          end

          def create
            render plain: "private r18 mutated"
          end

          private

          def require_dev_private_authentication!
            return if logged_in?

            sign_in_url = sign_app_sign_in_entrance_url(ri: params[:ri], host: oidc_sign_host)
            redirect_to_jump_url(sign_in_url)
          end

          def r18_content_required?
            true
          end

          def r18_gate_path(pt:)
            "/__dev/r18/gate?#{Rack::Utils.build_query(ri: params[:ri], pt: pt)}"
          end

          def r18_blocked_path
            blocked_acme_app___dev_r18_gate_path(ri: params[:ri])
          end

          def r18_stopped_path
            stopped_acme_app___dev_r18_gate_path(ri: params[:ri])
          end

          def r18_fallback_path
            acme_app_root_path(ri: params[:ri])
          end
        end
      end
    end
  end
end
