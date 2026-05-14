# typed: false
# frozen_string_literal: true

class RetentionPurgeJob < ApplicationJob
  queue_as :retention

  RETAINABLE_MODELS = %w(
    User Visitor Operator AppPreference OrgPreference ComPreference
    UserToken OperatorToken VisitorToken
    UserVerification OperatorVerification VisitorVerification
    UserAuthorizationCode OperatorAuthorizationCode VisitorAuthorizationCode
    UserReauthSession OperatorReauthSession VisitorReauthSession
    AreaOccurrence UserOccurrence VisitorOccurrence OperatorOccurrence ZipOccurrence
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
