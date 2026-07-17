GO ?= go
BINARY := bin/go9
LDFLAGS := -X github.com/GoSense9/go9/internal/buildinfo.Commit=$$(git rev-parse --short HEAD 2>/dev/null || echo unknown) -X github.com/GoSense9/go9/internal/buildinfo.Date=$$(date -u +%Y-%m-%dT%H:%M:%SZ)

.PHONY: build test vet run build-freebsd
build:
	$(GO) build -ldflags "$(LDFLAGS)" -o $(BINARY) ./cmd/go9

test:
	$(GO) test ./...

vet:
	$(GO) vet ./...

run: build
	$(BINARY) --role=init --control-socket $${GO9_CONTROL_SOCKET:-/tmp/go9-control.sock}

build-freebsd:
	CGO_ENABLED=0 GOOS=freebsd GOARCH=amd64 $(GO) build ./cmd/go9
