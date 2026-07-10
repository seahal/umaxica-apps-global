# typed: false
# frozen_string_literal: true

module AuthenticationContactabilityOwner
  extend ActiveSupport::Concern

  def contact_identifiers(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).contact_identifiers
  end

  def contact_identifier_count(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).contact_identifier_count
  end

  def contactable?(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).contactable?
  end

  def retains_contactability_after?(excluding:, reload: false)
    contactable?(excluding: excluding, reload: reload)
  end
end
