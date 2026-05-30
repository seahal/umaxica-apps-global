# typed: false
# frozen_string_literal: true

module SocialAuth
  class CallbackStateStore
    class << self
      def issue!(state:, provider:, intent: nil)
        state_class_for(provider)&.issue!(state: state, provider: provider, intent: intent)
      end

      def consume!(state:, provider:)
        state_class = state_class_for(provider)
        return false unless state_class

        state_class.consume!(state: state, provider: provider)
      end

      private

      def state_class_for(provider)
        case provider.to_s
        when "google_app", "apple"
          ClientSocialCallbackState
        when "google_org"
          OperatorSocialCallbackState
        end
      end
    end
  end
end
