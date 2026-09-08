# typed: false
# frozen_string_literal: true

# Outcome of Publishing::CreateEntryOperation.
#
# The only expected domain failure is a slug already taken in the same
# locale, which the `uidx_<cell>_slug_locale` unique index decides. Invalid
# input is rejected by Publishing::CreateEntryForm before the operation runs,
# and anything else raises.
class PublishingCreateEntryResult
  def self.success(entry)
    new(ok: true, entry: entry, errors: {})
  end

  def self.failure(errors)
    new(ok: false, entry: nil, errors: errors)
  end

  attr_reader :entry, :errors

  def initialize(ok:, entry:, errors:)
    @ok = ok
    @entry = entry
    @errors = errors
  end

  def ok?
    @ok
  end
end
