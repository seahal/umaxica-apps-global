# typed: false
# frozen_string_literal: true

module PromotionalEmailUnsubscribeHeaders
  extend ActiveSupport::Concern

  # Promotional unsubscribe links point at acme/www, which owns the preference and
  # email-unsubscribe boundary (adr/identity-authority-boundary.md). The legacy sign/id
  # preference endpoints have been removed.
  SURFACE_OPTIONS = {
    client: {
      edit_route: :edit_acme_app_preference_email_url,
      one_click_route: :acme_app_preference_email_url,
      host_env: "ACME_SERVICE_URL",
      default_host: "www.app.localhost",
    },
    visitor: {
      edit_route: :edit_acme_com_preference_email_url,
      one_click_route: :acme_com_preference_email_url,
      host_env: "ACME_CORPORATE_URL",
      default_host: "www.com.localhost",
    },
    operator: {
      edit_route: :edit_acme_org_preference_email_url,
      one_click_route: :acme_org_preference_email_url,
      host_env: "ACME_STAFF_URL",
      default_host: "www.org.localhost",
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
