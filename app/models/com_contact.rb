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

class ComContact < GuestRecord
  include ::PublicId

  attr_accessor :confirm_policy

  # Associations
  has_one :com_contact_email, dependent: :destroy, inverse_of: :com_contact
  has_one :com_contact_telephone, dependent: :destroy, inverse_of: :com_contact
  belongs_to :com_contact_category,
             class_name: "ComContactCategory",
             foreign_key: :category_id,
             primary_key: :id,
             inverse_of: :com_contacts
  belongs_to :com_contact_status,
             class_name: "ComContactStatus",
             foreign_key: :status_id,
             inverse_of: :com_contacts
  has_many :com_contact_topics, dependent: :destroy, inverse_of: :com_contact
  has_many :com_contact_chronicles,
           class_name: "ComContactChronicle",
           foreign_key: :subject_id,
           inverse_of: :com_contact,
           dependent: :delete_all

  after_initialize do
    if new_record?
      self.category_id = ComContactCategory::SECURITY_ISSUE if category_id.blank? || category_id.to_i.zero?
      self.status_id = ComContactStatus::NOTHING if status_id.blank? || status_id.to_i.zero?
    end
  end

  validates :confirm_policy, acceptance: true

  def completed?
    status_id == ComContactStatus::COMPLETED_CONTACT_ACTION
  end

  def to_param
    public_id
  end
end
