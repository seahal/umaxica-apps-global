# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class OutNoticesController < OpenController
      include ::Sign::OutNotice

      def show
        @sign_out_notice = consume_sign_out_notice
        return if @sign_out_notice.present?

        redirect_to(sign_com_root_path(ri: params[:ri]))
      end
    end
  end
end
