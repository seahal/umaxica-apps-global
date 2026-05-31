# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Dev
      module R18
        # TODO: Remove these temporary R18 smoke-test routes after R18 gate rollout is verified.
        class GatesController < Acme::App::ApplicationController
          include ::R18Gate

          AUTHENTICATION_MODE = :open
          class_attribute :r18_required_actions, default: Set.new # rubocop:disable ThreadSafety/ClassAndModuleAttributes
          before_action :require_r18_viewing!

          def show
            set_r18_no_store!
            render plain: "acme r18 gate"
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
            render plain: "acme r18 blocked"
          end

          def stopped
            set_r18_no_store!
            render plain: "acme r18 stopped"
          end

          private

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
