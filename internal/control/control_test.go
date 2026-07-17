package control

import (
	"context"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/GoSense9/go9/internal/platform"
)

func TestHandleSystemStatus(t *testing.T) {
	s := NewServer("", platform.NewProvider())
	r := s.Handle(Request{Operation: "system.status"})
	if !r.OK {
		t.Fatal(r.Error)
	}
}
func TestHandleUnknown(t *testing.T) {
	s := NewServer("", platform.NewProvider())
	if r := s.Handle(Request{Operation: "nope"}); r.OK {
		t.Fatal("expected failure")
	}
}
func TestCallReturnsErrorForFalseResponse(t *testing.T) {
	sock := filepath.Join(t.TempDir(), "control.sock")
	ln, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	go func() {
		c, err := ln.Accept()
		if err != nil {
			return
		}
		defer c.Close()
		var req Request
		_ = json.NewDecoder(c).Decode(&req)
		_ = json.NewEncoder(c).Encode(Response{OK: false, Error: "boom"})
	}()
	resp, err := Call(context.Background(), sock, "system.status")
	if err == nil {
		t.Fatal("expected error")
	}
	if resp.OK || err.Error() != "boom" {
		t.Fatalf("unexpected response/error: %+v %v", resp, err)
	}
}
func TestListenProtectsSocketPath(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("unix sockets only")
	}
	dir := t.TempDir()
	sock := filepath.Join(dir, "run", "go9", "control.sock")
	s := NewServer(sock, platform.NewProvider())
	if err := s.Listen(); err != nil {
		t.Fatal(err)
	}
	defer s.ln.Close()
	defer os.Remove(sock)
	if info, err := os.Stat(filepath.Dir(sock)); err != nil || info.Mode().Perm() != 0700 {
		t.Fatalf("dir mode = %v err %v", info.Mode().Perm(), err)
	}
	if info, err := os.Stat(sock); err != nil || info.Mode().Perm() != 0600 {
		t.Fatalf("socket mode = %v err %v", info.Mode().Perm(), err)
	}
}
func TestListenRefusesNonSocketPath(t *testing.T) {
	sock := filepath.Join(t.TempDir(), "control.sock")
	if err := os.WriteFile(sock, []byte("not a socket"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := NewServer(sock, platform.NewProvider()).Listen(); err == nil {
		t.Fatal("expected refusal")
	}
}
