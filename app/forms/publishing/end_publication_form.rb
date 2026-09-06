# typed: false
# frozen_string_literal: true

module Publishing
  # Input for ending a publication window.
  #
  # The reason is required because the database requires it: both
  # `chk_<cell>_pub_cancel` and `chk_<cell>_pub_term` make the reason column
  # `NOT NULL` as soon as the matching timestamp is set. Unpublishing without
  # saying why is not a state this schema can hold.
  class EndPublicationForm < ApplicationForm
    attribute :reason, :string

    validates :reason, presence: true

    def message_hash
      errors.details.to_h { |attribute, list|
        [attribute, message_for(attribute, list.first.fetch(:error))]
      }
    end

    private

    def message_for(attribute, error)
      if attribute == :reason && error == :blank
        "can't be blank"
      else
        error.to_s
      end
    end
  end
end
