# Architecture

GoSense9 ships as one `go9` executable with role-specific processes. `main` parses role flags, then delegates to packages under `internal/`.

- `bootstrap`: role and flag parsing.
- `supervisor`: development init process that starts child roles and restarts them by policy.
- `control`: JSON request/response Control API over a Unix socket.
- `console`: constrained interactive client; not a shell.
- `web`: server-rendered templates and HTMX; obtains status through the Control API.
- `platform`: system status provider with room for FreeBSD-specific code.
