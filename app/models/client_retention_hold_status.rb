# typed: false
# frozen_string_literal: true

class ClientRetentionHoldStatus < AppPrincipalRecord
  include ReferenceRecord

  ACTIVE = 10
  RELEASED = 20
  EXPIRED = 30
  DEFAULTS = [ACTIVE, RELEASED, EXPIRED].freeze
end
