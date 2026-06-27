# typed: false
# frozen_string_literal: true

module Base
  module App
    module Dev
      module R18
        # TODO: Remove these temporary R18 smoke-test routes after R18 gate rollout is verified.
        class OpenSmokesController < Base::App::ApplicationController
          include ::R18Gate

          AUTHENTICATION_MODE = :open
          class_attribute :r18_required_actions, default: Set.new # rubocop:disable ThreadSafety/ClassAndModuleAttributes
          before_action :require_r18_viewing!

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
            blocked_base_app___dev_r18_gate_path(ri: params[:ri])
          end

          def r18_stopped_path
            stopped_base_app___dev_r18_gate_path(ri: params[:ri])
          end

          def r18_fallback_path
            base_app_root_path(ri: params[:ri])
          end
        end
      end
    end
  end
end
