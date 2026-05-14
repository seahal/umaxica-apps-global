# typed: false
# frozen_string_literal: true

unless Rails.env.test?
  Sentry.init do |config|
    config.dsn = Rails.app.creds.option(:SENTRY_DSN_CONFIG)
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]

    # sentry-rails 6.4.1 still includes deprecated Rails constant by default.
    # Remove it to avoid deprecation warnings on Rails 8 / upcoming Rails 9.
    config.excluded_exceptions -= ["ActionController::InvalidAuthenticityToken"]

    # Add data like request headers and IP for users,
    # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
    config.send_default_pii = true
  end
end
