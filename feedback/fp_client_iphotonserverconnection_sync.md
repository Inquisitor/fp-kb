---
name: Keep IPhotonServerConnection in sync with PhotonServerConnection partials
description: When adding a public method or event to any PhotonServerConnection_*.cs partial in the FP client, also add the corresponding declaration in IPhotonServerConnection.cs -- the factory exposes the interface, not the concrete class.
type: feedback
---

The FP client's `PhotonConnectionFactory.Instance` returns `IPhotonServerConnection`, not the concrete
`PhotonServerConnection` class. Public methods and events added to any of the
`Assets/Photon Server Networking/PhotonServerConnection_*.cs` partials must be mirrored as declarations
in `Assets/Photon Server Networking/Interface/IPhotonServerConnection.cs`, otherwise call sites that go
through the factory (i.e. essentially all of UI) won't see the new API.

**Why:** Easy to miss. The concrete class compiles fine because partial classes share the type; only the
call sites that use the interface fail, and the symptom is "method shows red in IDE" rather than a build
error in the file you just edited. Found the hard way after the UI's
`PhotonConnectionFactory.Instance.MoveItemsOrCombine(...)` failed to resolve while the facade method
itself compiled cleanly.

**How to apply:** Whenever you touch a `PhotonServerConnection_*.cs` partial to add a `public` member,
open `IPhotonServerConnection.cs` in the same diff and add the matching `void`/`event` declaration near
related existing ones (e.g. batch counterparts go next to the single-item method, batch result events go
next to the single-item events).

This split does NOT exist on the server: there, `GameClientPeer` partials don't have an interface-facade
layer; server-side public additions are visible immediately.
