# typed: false
# frozen_string_literal: true

module Acme
  module App
    class FullAccessController < Acme::App::PreAccessController
      before_action :require_selected_actor_context!

      private

      def require_selected_actor_context!
        return if Actor.selection.selected?

        respond_to_missing_selected_context
      end

      def respond_to_missing_selected_context
        if request.format.json?
          render json: { status: "selection_required", next: acme_app_selector_path(ri: params[:ri]) }, status: :forbidden
        else
          redirect_to acme_app_selector_path(ri: params[:ri])
        end
      end
    end
  end
end
