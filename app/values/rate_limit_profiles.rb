# typed: false
# frozen_string_literal: true

module RateLimitProfiles
  Profile = Struct.new(:to, :within, :retry_after, keyword_init: true)
  AuthorizeProfileSet = Struct.new(:ip_surface, :browser_client, :client_redirect_host, keyword_init: true)

  module_function

  def page_view_get
    Profile.new(to: 120, within: 1.minute, retry_after: 60)
  end

  def interactive_post_ip
    Profile.new(to: 30, within: 1.minute, retry_after: 60)
  end

  def email_address_submit
    return Profile.new(to: 30, within: 10.minutes, retry_after: 600) unless Rails.env.production?

    Profile.new(to: 10, within: 10.minutes, retry_after: 600)
  end

  def credential_verify_subject
    Profile.new(to: 10, within: 10.minutes, retry_after: 600)
  end

  def credential_verify_ip
    Profile.new(to: 30, within: 1.minute, retry_after: 60)
  end

  def token_endpoint
    Profile.new(to: 30, within: 1.minute, retry_after: 60)
  end

  def oauth_authorize
    if Rails.env.production?
      AuthorizeProfileSet.new(
        ip_surface: Profile.new(to: 120, within: 1.minute, retry_after: 60),
        browser_client: Profile.new(to: 60, within: 1.minute, retry_after: 60),
        client_redirect_host: Profile.new(to: 600, within: 10.minutes, retry_after: 600),
      )
    else
      AuthorizeProfileSet.new(
        ip_surface: Profile.new(to: 300, within: 1.minute, retry_after: 60),
        browser_client: Profile.new(to: 120, within: 1.minute, retry_after: 60),
        client_redirect_host: Profile.new(to: 1000, within: 10.minutes, retry_after: 600),
      )
    end
  end
end
