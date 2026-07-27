# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  # Decides whether an external authentication provider may be used.
  #
  # NOTICE: no caller yet, and that is deliberate.
  #
  # Nothing invokes start_decision or callback_decision today. This port and its
  # environment adapter are complete and unit-tested, but how the decision is
  # invoked from the ceremony path is still an open design question, so wiring
  # is intentionally deferred. Adopting it is decided; only the calling style is
  # not.
  #
  # Do not read this absence as a defect, dead code, or an unfinished port, and
  # do not delete it as unused. Equally, do not treat the provider kill switch
  # as operational: until a caller exists, setting the availability environment
  # variables stops nothing. An audit that checks whether the kill switch
  # actually halts ceremonies should record it as not yet in force.
  #
  # When the calling style is settled, the gate belongs on the single ceremony
  # start path so login, signup, link, and step-up are covered once, and it must
  # run before any ceremony state, grant, or sign-up ticket is issued. Remove
  # this notice at that point.
  module ProviderAvailabilityPort
    def start_decision(provider:, operation:, context:)
      raise NotImplementedError
    end

    def callback_decision(provider:, ceremony:, context:)
      raise NotImplementedError
    end
  end
end
