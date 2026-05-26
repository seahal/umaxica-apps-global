# typed: false
# frozen_string_literal: true

module Apex
  module App
    module Dev
      module R18
        # TODO: Remove these temporary R18 smoke-test routes after R18 gate rollout is verified.
        class OpenController < Apex::App::OpenController
          include ::R18Gate

          AUTHENTICATION_MODE = :open

          def show
            render plain: "open r18 ok"
          end

          def create
            render plain: "open r18 mutated"
          end

          private

          def r18_content_required?
            true
          end

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
