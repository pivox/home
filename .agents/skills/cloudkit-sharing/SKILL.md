---
name: cloudkit-sharing
description: Use when changing À deux Core Data stores, CloudKit household sharing, invitation acceptance, shared identities, offline edits, or synchronization status.
---

# À deux household sharing

Read `Sources/DeuxPersistence/HouseholdStore.swift` and `ManagedModel.swift` first. `HouseholdRecord` is the shared root; task and completion children carry Codable snapshots. The model’s optional attributes, inverse relationships and root cascade rules support the shared graph. Preserve compatibility when changing persisted payloads or the model.

For every new child, assign it to `activeHousehold.objectID.persistentStore` and attach its `household` relationship. An invited household lives in the shared store: assigning all writes to the private store breaks its graph. Fetch children and UUIDs within the active household, and preserve atomic task/completion saves with rollback on failure.

Names can change without reassigning roles. `personOne` / `personTwo` are stable; `currentPerson` is local device identity. Reject `.anyone` for completion. Undo targets the latest remaining occurrence of that task and restores its previous due date; timestamp ordering alone may not distinguish simultaneous validations.

Trace native sharing through `App/CloudSharingSheet.swift`, `ShareInvitationDelegate.swift` and `AppServices.swift`. Capture the originating household/store before suspension; route callbacks by full `CKRecord.ID`, including zone, rather than whichever household is active later. Keep share persistence callbacks, cold/warm invitation paths, load-before-accept and visible retryable errors. `cloudEnabled` configures a capability; local saves and invitation acceptance do not prove import/export completion. Status must reflect actual container events.

Follow `docs/apple-setup.md` for real validation: configure Apple capabilities, use two distinct iCloud accounts, invite and accept, select the imported household and device identity, then add/complete from both devices. Exercise offline edits and reconnection, relaunch, historical undo and reminders on each identity. Record observed convergence and errors separately from local persistence tests. Never delete a user database to make a retry pass.
