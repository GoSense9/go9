package supervisor

import "testing"

func TestShouldRestart(t *testing.T) {
	if !ShouldRestart(RestartAlways, nil) {
		t.Fatal("always")
	}
	if !ShouldRestart(RestartOnFailure, assertErr{}) {
		t.Fatal("on failure")
	}
	if ShouldRestart(RestartNever, assertErr{}) {
		t.Fatal("never")
	}
}

type assertErr struct{}

func (assertErr) Error() string { return "err" }
