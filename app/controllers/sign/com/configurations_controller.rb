# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class ConfigurationsController < ApplicationController
      auth_required!
      before_action :authenticate_visitor!

      def show
      end

      def edit
        return if current_visitor.deactivated?

        safe_redirect_to(
          sign_com_configuration_path(ri: params[:ri]),
          fallback: sign_com_configuration_path,
        )
      end
    end
  end
end
