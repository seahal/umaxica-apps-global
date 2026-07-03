# typed: false
# frozen_string_literal: true

class VisitorRetentionHoldStatus < ComPrincipalRecord
  include ReferenceRecord

  ACTIVE = 10
  RELEASED = 20
  EXPIRED = 30
  DEFAULTS = [ACTIVE, RELEASED, EXPIRED].freeze
end
