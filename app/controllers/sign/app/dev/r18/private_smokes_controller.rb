# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Dev
      module R18
        # TODO: Remove these temporary R18 smoke-test routes after R18 gate rollout is verified.
        class PrivateSmokesController < Sign::App::ApplicationController
          include ::R18Gate

          AUTHENTICATION_MODE = :private
          class_attribute :r18_required_actions, default: Set.new # rubocop:disable ThreadSafety/ClassAndModuleAttributes
          before_action :require_r18_viewing!

          def show
            render plain: "private r18 ok"
          end

          def create
            render plain: "private r18 mutated"
          end

          private

          def handle_auth_required_html(_options = {})
            redirect_to(new_sign_app_sign_in_path(ri: params[:ri]), allow_other_host: false)
          end

          def r18_content_required?
            true
          end

          def r18_gate_path(pt:)
            "/r18/gate?#{Rack::Utils.build_query(ri: params[:ri], pt: pt)}"
          end

          def r18_blocked_path
            blocked_sign_app_r18_gate_path(ri: params[:ri])
          end

          def r18_stopped_path
            stopped_sign_app_r18_gate_path(ri: params[:ri])
          end

          def r18_fallback_path
            sign_app_dashboard_path(ri: params[:ri])
          end
        end
      end
    end
  end
end
