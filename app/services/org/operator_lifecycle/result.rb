# typed: false
# frozen_string_literal: true

module Org
  module OperatorLifecycle
    Result =
      Data.define(:success, :request, :error, :invitation) do
        def success? = !!success
      end
  end
end
