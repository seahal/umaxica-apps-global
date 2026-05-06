# Model-Layer Audit And Evidence Checklist

## Summary

This checklist tracks model-layer implementation readiness for audit and evidence work under the
four-app target.

It follows the current boundary draft:

- `activity` is the Identity canonical evidence layer
- `journal` is the Zenith canonical history layer
- `chronicle` is the Foundation detailed chronicle layer
- `publication` is the Distributor delivery layer

Foundation uses `chronicle`, not `behavior`.

## Scope

In scope for this checklist:

- event reference models
- event IDs and reference data
- activity, journal, chronicle, and publication record models
- model-adjacent persistence rules
- model and service tests that prove write behavior

## Boundary And Invariants

- [ ] `activity` is documented as the Identity canonical evidence layer
- [ ] `journal` is documented as the Zenith canonical history layer
- [ ] `chronicle` is documented as the Foundation detailed chronicle layer
- [ ] `publication` is documented as the Distributor delivery layer
- [ ] no active plan uses `behavior` as the Foundation target family name
- [ ] each write path has a clear database destination

## Activity Only: Identity Security

- [ ] `UserActivityEvent::LOGGED_IN`
- [ ] `UserActivityEvent::TOKEN_REFRESHED`
- [ ] `UserActivityEvent::PASSKEY_REGISTERED`
- [ ] `StaffActivityEvent::LOGGED_IN`
- [ ] `StaffActivityEvent::TOKEN_REFRESHED`

## Journal Only: Zenith Preference And Notification Root

- [ ] `AppPreferenceJournalEvent::CREATE_NEW_PREFERENCE_TOKEN`
- [ ] `AppPreferenceJournalEvent::UPDATE_PREFERENCE_COLORTHEME`
- [x] `NotificationJournalEvent::DEVICE_REGISTERED`
- [x] `NotificationJournalEvent::TOKEN_INVALIDATED`

## Publication Only: Distributor Content Delivery

- [ ] `AppDocumentPublicationEvent::PUBLISHED`
- [ ] `ComDocumentPublicationEvent::PUBLISHED`
- [ ] `OrgDocumentPublicationEvent::PUBLISHED`
- [ ] `AppTimelinePublicationEvent::PUBLISHED`
- [ ] `ComTimelinePublicationEvent::PUBLISHED`
- [ ] `OrgTimelinePublicationEvent::PUBLISHED`
- [ ] `PostPublicationEvent::VERSION_CREATED`

## Chronicle Only: Foundation Messaging, Search, Billing, And Contact

- [x] `MessageChronicleEvent::SENT`
- [x] `SearchChronicleEvent::QUERY_EXECUTED`
- [x] `BillingChronicleEvent::CHARGE_CREATED`
- [x] `ContactChronicleEvent::SUBMITTED`

## Deferred Cross-Boundary Work

- [ ] define paired Foundation chronicle write plus Distributor publication write where needed
- [ ] define Zenith summary projection from Foundation or Distributor writes where needed
- [ ] define correlation rules across activity, journal, chronicle, and publication
- [ ] assign engine write responsibility for each unchecked activity event
- [ ] assign engine write responsibility for each unchecked publication event

## Related

- `plans/analysis/audit-and-evidence-plan.md`
- `plans/active/foundation-distributor-db-boundary-plan.md`
