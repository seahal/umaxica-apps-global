# typed: false
# frozen_string_literal: true

module Auth
  class ContactContextBuilder
    # @param user [User, nil]
    # @return [Contact::ActorContext]
    def self.build_for_user(user)
      if user
        email = user.user_emails.to_a.find do |e|
          [UserEmailStatus::VERIFIED,
           UserEmailStatus::VERIFIED_WITH_SIGN_UP,].include?(e.user_email_status_id) && e.address.present?
        end || user.user_emails.to_a.find { |e| e.address.present? }

        telephone = user.user_telephones.to_a.find do |t|
          verified_statuses = [
            UserTelephoneStatus::VERIFIED,
            UserTelephoneStatus::VERIFIED_WITH_SIGN_UP,
          ]
          verified_statuses.include?(t.user_identity_telephone_status_id) && t.number.present?
        end || user.user_telephones.to_a.find { |t| t.number.present? }

        Contact::ActorContext.new(
          subject_type: "identified_member",
          subject_id: user.id.to_s,
          email: email&.address,
          telephone: telephone&.number,
        )
      else
        Contact::ActorContext.new(subject_type: "guest")
      end
    end

    # @param staff [Staff, nil]
    # @return [Contact::ActorContext]
    def self.build_for_staff(staff)
      if staff
        email = staff.staff_emails.to_a.find do |e|
          e.staff_identity_email_status_id == StaffEmailStatus::VERIFIED && e.address.present?
        end || staff.staff_emails.to_a.find { |e| e.address.present? }

        telephone = staff.staff_telephones.to_a.find do |t|
          t.staff_identity_telephone_status_id == StaffTelephoneStatus::VERIFIED && t.number.present?
        end || staff.staff_telephones.to_a.find { |t| t.number.present? }

        Contact::ActorContext.new(
          subject_type: "identified_member",
          subject_id: staff.id.to_s,
          email: email&.address,
          telephone: telephone&.number,
        )
      else
        Contact::ActorContext.new(subject_type: "guest")
      end
    end

    # @param customer [Customer, nil]
    # @return [Contact::ActorContext]
    def self.build_for_customer(customer)
      if customer
        Contact::ActorContext.new(
          subject_type: "guest",
          subject_id: customer.id.to_s,
          # customer models might not have the same email/telephone arrays if they are lightweight
          # depending on the actual implementation
          email: customer.respond_to?(:email) ? customer.email : nil,
          telephone: customer.respond_to?(:telephone) ? customer.telephone : nil,
        )
      else
        Contact::ActorContext.new(subject_type: "guest")
      end
    end
  end
end
