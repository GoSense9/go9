package control

import (
	"github.com/GoSense9/go9/internal/platform"
	"testing"
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
