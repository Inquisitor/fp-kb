# Backlog — FP-45678

- [ ] File D1 (as-is documentation) as a task under the epic — the epic currently holds only the
      three scoping defects, which is how FP-38395 stalled: preparation filed, target step never was
- [ ] Settle the boundary with FP-44798 before D3 starts: that epic owns "where the session record
      lives", this one owns "what a session is and who owns the state". Decide whether FP-45678
      depends on it or absorbs its sessions/`oc` item
- [ ] D3 must answer how Master routes a returning player to the specific `GameApplication` instance
      holding the session — today `SqlGameList` routes on room liveness only, and there is no notion
      of "this instance holds a detached session for this user"
- [ ] Assess the Photon `Actor`/`Peer` binding during D3 rather than assuming it away: `Actor.Peer`
      is a live reference and `LiteGame.RemovePeerFromGame` destroys the actor on disconnect, which
      gates reattach for a player still in a room
- [ ] Review the Fishing Together disconnect action as the reference implementation and as the
      anti-pattern: it proves a Room-scheduled timer outlives the peer, but its offline finish does a
      blocking profile load on the room fiber
