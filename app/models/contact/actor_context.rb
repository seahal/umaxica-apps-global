# typed: false
# frozen_string_literal: true

module Contact
  class ActorContext
    attr_reader :subject_type, :subject_id, :email, :telephone

    # @param subject_type [String] 'guest', 'anonymous_member', 'identified_member'
    # @param subject_id [String, nil] the canonical subject identifier (user_id, staff_id, customer_id)
    # @param email [String, nil] canonical email address
    # @param telephone [String, nil] canonical telephone number
    def initialize(subject_type:, subject_id: nil, email: nil, telephone: nil)
      @subject_type = subject_type
      @subject_id = subject_id
      @email = email
      @telephone = telephone
    end

    def guest?
      subject_type == "guest"
    end

    def anonymous_member?
      subject_type == "anonymous_member"
    end

    def identified_member?
      subject_type == "identified_member"
    end
  end
end
