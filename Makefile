GO ?= go
BINARY := bin/go9
LDFLAGS := -X github.com/GoSense9/go9/internal/buildinfo.Commit=$$(git rev-parse --short HEAD 2>/dev/null || echo unknown) -X github.com/GoSense9/go9/internal/buildinfo.Date=$$(date -u +%Y-%m-%dT%H:%M:%SZ)

.PHONY: build test vet run build-freebsd freebsd-vm-up freebsd-vm-provision freebsd-vm-test freebsd-vm-shell freebsd-vm-logs freebsd-vm-down freebsd-vm-clean freebsd-dev
build:
	mkdir -p bin
	$(GO) build -ldflags "$(LDFLAGS)" -o $(BINARY) ./cmd/go9

test:
	$(GO) test ./...

vet:
	$(GO) vet ./...

run: build
	$(BINARY) --role=init --control-socket $${GO9_CONTROL_SOCKET:-/tmp/go9-control.sock}

build-freebsd:
	mkdir -p bin
	CGO_ENABLED=0 GOOS=freebsd GOARCH=amd64 $(GO) build -o bin/go9-freebsd-amd64 ./cmd/go9


freebsd-vm-up:
	freebsd/devvm/up.sh

freebsd-vm-provision:
	freebsd/devvm/provision.sh

freebsd-vm-test:
	freebsd/devvm/test.sh

freebsd-vm-shell:
	freebsd/devvm/shell.sh

freebsd-vm-logs:
	freebsd/devvm/logs.sh

freebsd-vm-down:
	freebsd/devvm/down.sh

freebsd-vm-clean:
	freebsd/devvm/clean.sh

freebsd-dev:
	freebsd/devvm/up.sh
	freebsd/devvm/provision.sh
	freebsd/devvm/test.sh
