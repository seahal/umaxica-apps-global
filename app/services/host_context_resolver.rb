# typed: false
# frozen_string_literal: true

class HostContextResolver
  Context = Data.define(:surface, :account, :tenant)

  def self.call(request)
    Context.new(
      surface: Core::Surface.current(request),
      account: nil,
      tenant: nil,
    )
  end
end
