# typed: false
# frozen_string_literal: true

# Transitional seam for interactive browser session commits.
#
# Controllers still own HTTP response decisions, but they should not reach
# directly into the low-level sign-in helper. This seam keeps the current
# Rails session behavior stable while making the authority boundary explicit.
class AuthenticationSessionCommitter
  def self.call(controller:, resource:, **)
    new(controller: controller).call(resource: resource, **)
  end

  def initialize(controller:)
    @controller = controller
  end

  def call(resource:, **)
    @controller.send(:establish_signed_in_session!, resource, **)
  end
end
