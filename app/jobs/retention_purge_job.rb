# typed: false
# frozen_string_literal: true

class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  RETAINABLE_MODELS = %w(
    User Customer Staff AppPreference OrgPreference ComPreference
    UserToken StaffToken CustomerToken
    UserVerification StaffVerification CustomerVerification
    UserAuthorizationCode StaffAuthorizationCode CustomerAuthorizationCode
    UserReauthSession StaffReauthSession CustomerReauthSession
    AreaOccurrence UserOccurrence StaffOccurrence ZipOccurrence
    DomainOccurrence IpOccurrence EmailOccurrence JwtOccurrence TelephoneOccurrence
    AppJumpLink ComJumpLink OrgJumpLink
  ).filter_map(&:safe_constantize).freeze

  def perform(batch_size: 500)
    now = Time.current
    RETAINABLE_MODELS.each do |klass|
      klass.where(purge_at: ..now).in_batches(of: batch_size).delete_all
    end
  end
end
