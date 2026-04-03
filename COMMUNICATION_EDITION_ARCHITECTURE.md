# Communication Edition Architecture

## Goal

Turn the dashboard's right rail into the first surface of a real school communication system:

- teacher-to-teacher communication
- department and grade-team groups
- admin alerts and announcements
- shared files and pinned resources
- desktop rail plus a dedicated mobile communication destination

The communication layer should increase school adoption without muddying the core teaching workflow.

## Source Of Truth

Communication should be cloud-first only.

Reason:

- chat, alerts, unread state, and file sharing need a shared source of truth
- local-first is strong for solo-teacher academic workflow, but it is the wrong contract for multi-user communication
- admin broadcasts and staff groups need role-aware visibility, not device-local state

Recommended rule:

- academic workflow can remain hybrid
- communication uses Firebase Auth + Firestore + Storage only

## Product Surfaces

### Desktop

- dashboard right rail becomes the always-visible communication hub
- includes admin alerts, staff channels, unread activity, and pinned resources
- secondary to teaching workflow, but always available

### Tablet

- communication rail moves into the main scroll after the top summary
- unread and alerts stay visible, but do not permanently consume a third column

### Mobile

- dedicated `Communication` destination in bottom navigation
- stacked tabs inside communication for `Alerts`, `Channels`, `Direct`, and `Files`
- dashboard remains teaching-first

## Roles

- `admin`
  - can broadcast school-wide alerts
  - can manage channels and memberships
  - can pin notices and moderate communication spaces
- `departmentLead`
  - can post department-wide alerts
  - can manage department channels
  - can pin shared resources for their team
- `teacher`
  - can participate in allowed channels
  - can send direct messages and upload files where permitted

## Core Firestore Shape

Suggested top-level structure:

```text
schools/{schoolId}
schools/{schoolId}/memberships/{userId}
schools/{schoolId}/channels/{channelId}
schools/{schoolId}/channels/{channelId}/messages/{messageId}
schools/{schoolId}/alerts/{alertId}
schools/{schoolId}/files/{fileId}
schools/{schoolId}/directThreads/{threadId}
schools/{schoolId}/directThreads/{threadId}/messages/{messageId}
```

Important documents:

- `memberships`
  - role
  - departments
  - teams
  - active / archived
- `channels`
  - kind: `announcement`, `staff`, `department`, `gradeTeam`, `support`
  - visibility rules
  - membership rules
  - pinned message ids
- `alerts`
  - severity
  - audience
  - requires acknowledgement
  - created by
  - expires at
- `files`
  - storage path
  - uploader
  - linked channel or alert
  - visibility scope

## Security Direction

- auth required for all communication reads and writes
- every document is scoped to a school id
- channel reads depend on membership and role
- alerts can be school-wide, department-scoped, or team-scoped
- file access inherits channel or alert visibility
- admin actions should be auditable

## Phased Delivery

### Phase 1

- admin alerts
- staff channel list
- department channel list
- right-rail communication hub
- mobile communication tab shell

### Phase 2

- live channel messaging
- unread state
- pinned posts
- direct teacher messages

### Phase 3

- file sharing
- mentions
- search
- notification preferences

### Phase 4

- moderation tools
- acknowledgement tracking for urgent alerts
- archived channels
- admin analytics for communication reach

## What This Repo Now Supports

This pass establishes the product and code foundation:

- communication domain models
- a communication workspace service
- dashboard copy and summary metrics that point toward admin alerts and staff channels
- a right rail that now reads as a communication surface instead of a generic live desk

This is still a preview layer, not full real-time chat.

## Next Safe Implementation Step

Build a Firestore-backed `CommunicationRepository` with:

- school memberships
- alert documents
- channel documents
- unread counters per user

That is the smallest technical milestone that turns the rail from presentation into real school communication.
