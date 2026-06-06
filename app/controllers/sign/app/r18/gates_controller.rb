# typed: false
# frozen_string_literal: true

module Sign
  module App
    module R18
      class GatesController < ::Sign::App::ApplicationController
        include ::R18Gate

        AUTHENTICATION_MODE = :open
        class_attribute :r18_required_actions, default: Set.new # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        before_action :require_r18_viewing!

        def show
          set_r18_no_store!
          render plain: I18n.t("sign.app.r18.gate.question", default: "あなたは18歳以上ですか？"), status: :ok
        end

        def create
          set_r18_no_store!
          return redirect_to(r18_fallback_path, allow_other_host: false) if params[:decision] == "cancel"
          return redirect_to(r18_blocked_path, allow_other_host: false) unless
            ActiveModel::Type::Boolean.new.cast(params[:yes]) || params.expect(:decision).in?(%w(view allow))

          if logged_in?
            acknowledge_r18_view_once!
          else
            acknowledge_r18!
          end

          redirect_to(r18_safe_pt(params[:pt]), allow_other_host: false)
        end

        def blocked
          set_r18_no_store!
          render plain: I18n.t("sign.app.r18.blocked", default: "このコンテンツは閲覧できません。"), status: :ok
        end

        def stopped
          set_r18_no_store!
          render plain: I18n.t("sign.app.r18.stopped", default: "18禁コンテンツの表示は一時停止中です。"), status: :ok
        end

        private

        def r18_gate_path(pt:)
          sign_app_r18_gate_path(ri: params[:ri], pt: pt)
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
