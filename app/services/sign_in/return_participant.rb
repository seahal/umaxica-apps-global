# typed: false
# frozen_string_literal: true

module SignIn
  class ReturnParticipant
    attr_reader :cycle, :default_path

    def initialize(cycle:, default_path:)
      @cycle = cycle
      @default_path = default_path
    end

    def consume!
      cycle.class.transaction do
        cycle.lock!

        destination = safe_pt_path(cycle.return_to) || default_path
        cycle.update!(return_to: nil) if cycle.return_to.present?
        cycle.complete_sign_in!

        destination
      end
    end

    private

    def safe_pt_path(value)
      result = Redirects::PathTargetResolver.call(value, source: :sign_in_flow_return)
      result.value if result.ok?
    end
  end
end
