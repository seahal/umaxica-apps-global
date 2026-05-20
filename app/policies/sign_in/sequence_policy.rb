# typed: false
# frozen_string_literal: true

module SignIn
  class SequencePolicy < ApplicationPolicy
    def show_checkpoint?
      checkpoint_allowed?
    end

    def update_checkpoint?
      checkpoint_allowed?
    end

    def destroy_checkpoint?
      checkpoint_allowed?
    end

    private

    def checkpoint_allowed?
      record.respond_to?(:valid_for?) &&
        record.valid_for?(surface: record.surface || Actor.tld, actor: user, participant: :checkpoint)
    end
  end
end
