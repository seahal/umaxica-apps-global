# typed: false
# frozen_string_literal: true

require "openssl"
require "ipaddr"

module OccurrenceHmac
  module_function

  class MissingSecretError < ApplicationError
    def initialize
      super("errors.occurrence.missing_hmac_secret_credential")
    end
  end

  class InvalidTelephoneFormatError < ApplicationError
    def initialize
      super("errors.occurrence.invalid_telephone_format")
    end
  end

  def email_hmac(email)
    normalized = email.to_s.strip.downcase
    digest(kind: :email, body: normalized)
  end

  def telephone_hmac(telephone)
    normalized = telephone.to_s.strip
    raise InvalidTelephoneFormatError if normalized.blank?
    raise InvalidTelephoneFormatError unless normalized.start_with?("+")
    raise InvalidTelephoneFormatError unless normalized.match?(/\A\+\d+\z/)

    digest(kind: :telephone, body: normalized)
  end

  def ip_hmac(ip)
    normalized = ip.to_s.strip
    digest(kind: :ip, body: normalized)
  end

  # HMAC of the coarse network the IP belongs to (/24 for IPv4, /48 for IPv6)
  # rather than the full address. Used as a same-session change signal for
  # anomaly detection (see adr/ip-anomaly-session-revocation.md). The coarse
  # prefix tolerates ordinary in-carrier/NAT IP churn while still detecting a
  # network-level change. Returns nil for a blank/unparseable address so callers
  # can skip the comparison rather than treat it as a change.
  def network_hmac(ip)
    network = network_prefix(ip)
    return nil if network.blank?

    digest(kind: :network, body: network)
  end

  # Returns the masked network string ("203.0.113.0/24" or "2001:db8::/48"),
  # or nil when the address is blank or not a valid IP.
  def network_prefix(ip)
    normalized = ip.to_s.strip
    return nil if normalized.blank?

    addr = IPAddr.new(normalized)
    prefix = addr.ipv4? ? 24 : 48
    masked = addr.mask(prefix)
    "#{masked}/#{prefix}"
  rescue IPAddr::Error
    nil
  end

  def digest(kind:, body:)
    OpenSSL::HMAC.hexdigest("SHA256", secret_credential, "#{kind}:#{body}")
  end

  def secret_credential
    secret_credential_value = Rails.app.creds.option(:OCCURRENCE_HMAC_SECRET)
    raise MissingSecretError if secret_credential_value.blank?

    secret_credential_value
  end
end
