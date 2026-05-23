# typed: false
# frozen_string_literal: true

module Jump
  module Org
    class OpenController < BareController
      include ::ActorSupport

      before_action :set_current_context
      before_action :set_current_actor
      prepend_around_action :with_actor_lifecycle

      public_strict!
    end
  end
end
