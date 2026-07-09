# FP-44875 - Backlog

- [x] Server-side guard for node Stop: `HomeController.Stop` is an unguarded GET, so confirm() covers the UI only (bookmarks / direct URL / stale links bypass it). Consider rejecting Stop for a node with players online unless an explicit force flag is passed. Needs an SD rebuild + redeploy, out of the view-only fix scope. -> Bubbled up to `fishing-planet/server/backlog.md` on close (2026-07-09).
