# typed: false
# frozen_string_literal: true

OrgOperatorLifecycleResult =
  Data.define(:success, :request, :error, :invitation) do
    def success? = !!success
  end
