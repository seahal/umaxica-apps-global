# typed: false
# frozen_string_literal: true

class Sign::Com::Settings::Revocations::AllsController < ::Sign::Com::ApplicationController
  AUTHENTICATION_MODE = :private

  before_action :authenticate_visitor!

  def create
    current_visitor.visitor_tokens.session_inventory.find_each(&:revoke!)
    redirect_to(sign_com_sign_out_path(ri: params[:ri]), status: :see_other)
  end
end
