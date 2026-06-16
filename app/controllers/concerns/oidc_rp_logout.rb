# typed: false
# frozen_string_literal: true

module OidcRpLogout
  extend ActiveSupport::Concern

  def create
    log_out
    redirect_to("/", allow_other_host: false, status: :see_other)
  end
end
