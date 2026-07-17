# Repository guidance for Codex

- Preserve the naming distinction: public product/project/release name is `GoSense9`; internal technical name, executable, paths, sockets, packages, services, process roles, and prompts use `go9`.
- Prefer the Go standard library and minimal dependencies.
- Keep PID 1/init behavior minimal; avoid adding production PID 1 semantics without an ADR.
- Do not execute arbitrary shell commands from the console, web UI, or Control API.
- Run `go test ./...`, `go vet ./...`, a native build, and `CGO_ENABLED=0 GOOS=freebsd GOARCH=amd64 go build ./cmd/go9` before completing tasks.
- Use Architecture Decision Records for consequential design changes.
