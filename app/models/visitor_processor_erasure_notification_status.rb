# typed: false
# frozen_string_literal: true

class VisitorProcessorErasureNotificationStatus < ComPrincipalRecord
  include ReferenceRecord

  PENDING = 10
  NOTIFIED = 20
  FAILED = 30
  SKIPPED = 40
  DEFAULTS = [PENDING, NOTIFIED, FAILED, SKIPPED].freeze
end
