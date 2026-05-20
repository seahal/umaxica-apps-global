# typed: false
# frozen_string_literal: true

module Preference
  module WebCookieActions
    extend ActiveSupport::Concern

    def show
      render json: cookie_consent_state, status: :ok
    end

    def update
      apply_consented_update_from_request!
      set_consented_buffer_cookie!
      render json: cookie_consent_state, status: :ok
    end
  end
end
