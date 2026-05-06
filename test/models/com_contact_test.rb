# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: com_contacts
# Database name: guest
#
#  id               :bigint           not null, primary key
#  ip_address       :inet
#  token            :string(32)       default(""), not null
#  token_digest     :string
#  token_expires_at :datetime
#  token_viewed     :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  category_id      :bigint           default(0), not null
#  public_id        :string(21)       not null
#  status_id        :bigint           not null
#
# Indexes
#
#  index_com_contacts_on_category_id       (category_id)
#  index_com_contacts_on_public_id         (public_id) UNIQUE
#  index_com_contacts_on_status_id         (status_id)
#  index_com_contacts_on_token             (token)
#  index_com_contacts_on_token_digest      (token_digest)
#  index_com_contacts_on_token_expires_at  (token_expires_at)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => com_contact_categories.id)
#  fk_rails_...  (status_id => com_contact_statuses.id) ON DELETE => restrict
#
require "test_helper"

class ComContactTest < ActiveSupport::TestCase
  def build_contact(**attrs)
    contact = ComContact.new(**attrs.except(:com_contact_email, :com_contact_telephone))
    contact.confirm_policy = "1" unless attrs.key?(:confirm_policy)
    contact.category_id ||= sample_category
    contact.status_id ||= sample_status
    contact.save!

    unless attrs.key?(:com_contact_email)
      ComContactEmail.create!(
        com_contact: contact,
        email_address: "test@example.com",
        expires_at: 1.day.from_now,
      )
    end

    unless attrs.key?(:com_contact_telephone)
      ComContactTelephone.create!(
        com_contact: contact,
        telephone_number: "+1234567890",
        expires_at: 1.day.from_now,
      )
    end

    contact
  end

  setup do
    create_all_statuses
    create_all_categories
  end

  def sample_category
    ComContactCategory::SECURITY_ISSUE
  end

  def sample_status
    ComContactStatus::NOTHING
  end

  def create_all_statuses
    statuses = [
      ComContactStatus::NOTHING,
      ComContactStatus::SET_UP,
      ComContactStatus::NULL_COM_STATUS,
      ComContactStatus::COMPLETED_CONTACT_ACTION,
    ]
    statuses.each do |id|
      ComContactStatus.find_or_create_by!(id: id)
    end
  end

  def create_all_categories
    categories = [
      ComContactCategory::NOTHING,
      ComContactCategory::SECURITY_ISSUE,
    ]
    categories.each do |id|
      ComContactCategory.find_or_create_by!(id: id)
    end
  end

  test "should inherit from GuestRecord" do
    assert_operator ComContact, :<, GuestRecord
  end

  test "should set default category and status when nil" do
    contact = ComContact.new(category_id: nil, status_id: nil, confirm_policy: "1")

    assert contact.save
    assert_equal ComContactCategory::SECURITY_ISSUE, contact.category_id
    assert_equal ComContactStatus::NOTHING, contact.status_id
  end

  test "should generate public_id on create" do
    contact = ComContact.new(confirm_policy: "1")
    contact.save!

    assert_not_nil contact.public_id
    assert_equal 21, contact.public_id.length
  end

  test "association deletion: destroys dependent email, telephone, and topics" do
    contact = build_contact
    email = contact.com_contact_email
    phone = contact.com_contact_telephone
    topic = ComContactTopic.create!(com_contact: contact, title: "Test title", description: "Test body")

    contact.destroy
    assert_raise(ActiveRecord::RecordNotFound) { email.reload }
    assert_raise(ActiveRecord::RecordNotFound) { phone.reload }
    assert_raise(ActiveRecord::RecordNotFound) { topic.reload }
  end

  test "to_param returns public_id" do
    contact = build_contact

    assert_equal contact.public_id, contact.to_param
  end

  test "completed? reflects completed contact action status" do
    contact = ComContact.new(status_id: ComContactStatus::COMPLETED_CONTACT_ACTION)

    assert_predicate contact, :completed?
  end
end
