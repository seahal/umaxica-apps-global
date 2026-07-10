# typed: false
# frozen_string_literal: true

module AuthenticationAal2CredentialOwner
  extend ActiveSupport::Concern

  def aal2_methods(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).aal2_methods
  end

  def step_up_methods(excluding: nil, reload: false)
    aal2_methods(excluding: excluding, reload: reload)
  end

  def aal2_method_count(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).aal2_method_count
  end

  def aal2_available?(excluding: nil, reload: false)
    authentication_credential_inventory(excluding: excluding, reload: reload).aal2_available?
  end

  def step_up_available?(excluding: nil, reload: false)
    aal2_available?(excluding: excluding, reload: reload)
  end

  def retains_aal2_after?(excluding:, reload: false)
    aal2_available?(excluding: excluding, reload: reload)
  end

  def retains_step_up_after?(excluding:, reload: false)
    retains_aal2_after?(excluding: excluding, reload: reload)
  end
end
