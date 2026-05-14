# typed: false
# frozen_string_literal: true

module PromotionalEmailUnsubscribeHeaders
  extend ActiveSupport::Concern

  SURFACE_OPTIONS = {
    client: {
      edit_route: :edit_sign_app_preference_email_url,
      one_click_route: :sign_app_preference_email_url,
      host_env: "SIGN_SERVICE_URL",
      default_host: "id.app.localhost",
    },
    visitor: {
      edit_route: :edit_sign_com_preference_email_url,
      one_click_route: :sign_com_preference_email_url,
      host_env: "SIGN_CORPORATE_URL",
      default_host: "id.com.localhost",
    },
    operator: {
      edit_route: :edit_sign_org_preference_email_url,
      one_click_route: :sign_org_preference_email_url,
      host_env: "SIGN_STAFF_URL",
      default_host: "id.org.localhost",
    },
  }.freeze

  private

  def set_promotional_unsubscribe_headers(email_record)
    one_click_url = promotional_unsubscribe_url(email_record, route: :one_click_route)

    headers["List-Unsubscribe"] = "<#{one_click_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
  end

  def promotional_unsubscribe_edit_url(email_record)
    promotional_unsubscribe_url(email_record, route: :edit_route)
  end

  def promotional_unsubscribe_url(email_record, route:)
    options = SURFACE_OPTIONS.fetch(email_record.promotional_unsubscribe_scope)
    token = email_record.promotional_unsubscribe_token

    Rails.application.routes.url_helpers.public_send(
      options.fetch(route),
      email_record,
      token: token,
      host: ENV.fetch(options.fetch(:host_env), options.fetch(:default_host)),
    )
  end
end
