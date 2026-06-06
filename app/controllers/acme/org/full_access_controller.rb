# typed: false
# frozen_string_literal: true

module Acme
  module Org
    class FullAccessController < Acme::Org::PreAccessController
      AUTHENTICATION_MODE = :private

      before_action :require_selected_actor_context!

      private

      def require_selected_actor_context!
        return if Actor.selection.selected?

        if request.format.json?
          render json: { status: "selection_required", next: acme_org_selector_path(ri: params[:ri]) },
                 status: :forbidden
        else
          redirect_to(acme_org_selector_path(ri: params[:ri]))
        end
      end
    end
  end
end
