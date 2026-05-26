# typed: false
# frozen_string_literal: true

module Apex
  module App
    module Dev
      module R18
        # TODO: Remove these temporary R18 smoke-test routes after R18 gate rollout is verified.
        class GatesController < Apex::App::OpenController
          include ::R18Gate

          AUTHENTICATION_MODE = :open

          def show
            set_r18_no_store!
            render plain: "apex r18 gate"
          end

          def create
            set_r18_no_store!
            return redirect_to(r18_fallback_path, allow_other_host: false) if params[:decision] == "cancel"

            acknowledge_r18_view_once!
            acknowledge_r18! unless logged_in?
            redirect_to(r18_safe_pt(params[:pt]), allow_other_host: false)
          end

          def blocked
            set_r18_no_store!
            render plain: "apex r18 blocked"
          end

          def stopped
            set_r18_no_store!
            render plain: "apex r18 stopped"
          end

          private

          def r18_gate_path(pt:)
            "/__dev/r18/gate?#{Rack::Utils.build_query(ri: params[:ri], pt: pt)}"
          end

          def r18_blocked_path
            blocked_apex_app___dev_r18_gate_path(ri: params[:ri])
          end

          def r18_stopped_path
            stopped_apex_app___dev_r18_gate_path(ri: params[:ri])
          end

          def r18_fallback_path
            apex_app_root_path(ri: params[:ri])
          end
        end
      end
    end
  end
end
