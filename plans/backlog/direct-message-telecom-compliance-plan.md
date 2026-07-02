# Direct Message Telecom Compliance Plan

## Japanese Abstract

1 on 1 direct message is likely a telecommunications business feature in Japan. This plan tracks the
compliance work before the feature becomes real. The main regulator is the Ministry of Internal
Affairs and Communications.

## Summary

This repository previously contained a local direct-message skeleton. The route placeholder and
`DirectMessageThread` model/table were retired in June 2026 because current boundary docs classify
direct message behavior as regional `line` work, not global-repository behavior.

Current boundary docs classify direct message behavior as regional `line` work. Before any
production direct message implementation proceeds, an ADR or active plan must decide which
repository owns it and how telecom compliance gates are enforced.

However, the current implementation does not yet show the legal and operational controls that are
normally required when a service mediates user-to-user communication in Japan.

For this project, we should treat one-to-one direct messaging as a feature that requires explicit
telecom compliance review before production release.

## Why This Needs a Separate Track

Direct messaging is not only a product feature. It changes the regulatory posture of the service.

The implementation must not proceed as a normal CRUD feature only. It needs:

- a legal qualification check under the Telecommunications Business Act
- regulator-facing filing and consultation work
- user-facing notice and contract updates
- operational controls for retention, disclosure response, deletion, and incident handling

## Confirmed Repository State

The following state is current after the June 2026 retirement:

- `config/routes/line.rb` and `draw :line` are removed.
- `DirectMessageThread` and its model test are removed.
- `direct_message_threads` is dropped by a reversible message-database migration.
- The `message` database connection remains temporarily so the drop migration can run before the
  connection is fully retired.

This means the codebase no longer signals an active local direct-message product skeleton.

## Scope

This plan covers:

- legal qualification review for one-to-one direct message
- implementation gating before production rollout
- user-facing documentation that must exist before launch
- issue decomposition for tracking

This plan does not yet cover:

- communication secrecy operational design in detail
- final data retention duration decisions
- a final legal opinion for any non-Japan jurisdiction

## Working Assumption

Until specialist counsel or MIC consultation says otherwise, assume:

- one-to-one direct message is in scope for telecom filing review in Japan
- launch must be blocked until the filing path is clear
- the product must ship with clear user-facing notice and internal operating procedures

## Delivery Tracks

### Track A: Legal Qualification And Filing Readiness

Goal: Confirm whether the planned direct message feature requires filing, what type of filing is
needed, and what conditions must be met before launch.

Minimum outputs:

- a repository note that states the current legal assumption
- an internal checklist for MIC consultation or filing preparation
- a release gate that prevents silent rollout before legal review completion

### Track B: User-Facing Documentation

Goal: Prepare the minimum user-visible documents required to explain the messaging feature and its
data handling.

Minimum outputs:

- terms update for direct message usage rules
- privacy notice update for message-related personal data
- service notice that explains moderation, disclosure response, and retention at a high level

### Track C: Operational Readiness

Goal: Define the operational controls for evidence preservation and regulated response handling.

Minimum outputs:

- disclosure request handling flow
- deletion and retention flow
- incident and outage communication flow
- traceability for message-related actions

## Proposed Sequence

1. Freeze the current legal assumption in a plan document.
2. Open GitHub issues for the legal, document, and operations tracks.
3. Do not reintroduce message endpoints or message persistence until the legal gate is satisfied.
4. Implement the user-facing documents before any production-ready messaging workflow.
5. Design the operations flow for retention, disclosure response, and incidents.
6. Only then move to full message persistence and product rollout.

## Release Gate

Do not consider direct messaging launch-ready until all of the following are true:

- the legal qualification work is complete
- counsel or MIC-facing filing review confirms whether telecommunications business notification or
  registration is required in Japan
- the filing path has been confirmed
- user-facing documents are drafted and approved
- operations for retention and disclosure are defined

Until that gate is satisfied, do not reintroduce `DirectMessageThread`, message persistence, message
routes, controller skeletons, background jobs, or UI placeholders in this repository. Resume product
and technical design only after legal and filing confirmation is complete.

## Issue Mapping

Recommended issue split:

1. Legal qualification and MIC filing readiness for one-to-one direct messaging
2. User-facing terms and privacy notice for direct messaging
3. Message retention, disclosure response, deletion, and incident operations
