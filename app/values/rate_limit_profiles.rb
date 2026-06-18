# typed: false
# frozen_string_literal: true

module RateLimitProfiles
  Profile = Struct.new(:to, :within, :retry_after, keyword_init: true)

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
end
