# typed: false
# frozen_string_literal: true

module RouteHelpers
  extend ActiveSupport::Concern

  included do
    helper_method :sign_app_social_start_url if respond_to?(:helper_method)
  end

  def sign_app_social_start_url(options = {})
    new_sign_app_social_session_url(options.reverse_merge(host: "id.app.localhost"))
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include RouteHelpers }
