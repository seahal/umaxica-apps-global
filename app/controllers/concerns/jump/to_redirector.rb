# typed: false
# frozen_string_literal: true

module Jump::ToRedirector
  extend ActiveSupport::Concern

  included do
    skip_before_action :apply_localization_preferences, raise: false
    before_action :disable_cookie_session
  end

  def show
    jump_link_model = self.class::JUMP_LINK_MODEL
    jump_link = jump_link_model.find_by(public_id: params[:public_id])
    return head :not_found if jump_link.blank?

    destination_url =
      RedirectorRecord.connected_to(role: :writing) do
        jump_link.consume_destination_for(user: nil)
      end
    return head :not_found if destination_url.blank?

    # Validate destination URL against allowlist
    unless validate_destination_url!(destination_url)
      Rails.event.notify("redirect.blocked", host: extract_host(destination_url), public_id: params[:public_id])
      return head :not_found
    end

    response.set_header("Referrer-Policy", "no-referrer")

    Rails.logger.silence do
      redirect_to(destination_url, allow_other_host: true)
    end
  end

  private

  def disable_cookie_session
    request.session_options[:skip] = true
  end

  # Validates destination URL scheme and host against allowlist
  def validate_destination_url!(url)
    uri = URI.parse(url)

    # Reject non-http(s) schemes
    return false unless uri.scheme&.downcase&.in?(%w(http https))

    # Validate host against allowlist
    allowed_jump_host?(uri)
  rescue URI::InvalidURIError
    false
  end

  def extract_host(url)
    URI.parse(url).host
  rescue URI::InvalidURIError
    nil
  end

  # Check if the URI's host is in the allowed list
  def allowed_jump_host?(uri)
    allowed_hosts.include?(uri.host&.downcase)
  end

  # Returns list of allowed hosts for jump redirects
  def allowed_hosts
    # Use JUMP_ALLOWED_HOSTS env var (comma-separated) or fallback to empty array
    hosts = ENV.fetch("JUMP_ALLOWED_HOSTS", "").split(",").map { |x| x.strip.downcase }
    hosts.compact_blank
  end
end
