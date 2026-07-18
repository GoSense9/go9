package console

import (
	"context"
	"io"
	"strings"
	"testing"
	"time"
)

func TestParseCommand(t *testing.T) {
	cases := map[string]Command{"help": CmdHelp, "version": CmdVersion, "system status": CmdSystemStatus, " exit ": CmdExit, "rm -rf /": CmdUnknown}
	for in, want := range cases {
		if got := ParseCommand(in); got != want {
			t.Fatalf("%q got %v want %v", in, got, want)
		}
	}
}
func TestRunStopsWhenContextCancelledWhileWaitingForInput(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	pr, _ := io.Pipe()
	done := make(chan error, 1)
	go func() { done <- Run(ctx, pr, io.Discard, "") }()
	cancel()
	select {
	case err := <-done:
		if err == nil || err != context.Canceled {
			t.Fatalf("error = %v", err)
		}
	case <-time.After(time.Second):
		t.Fatal("console did not stop promptly")
	}
}
func TestRunExit(t *testing.T) {
	if err := Run(context.Background(), strings.NewReader("exit\n"), io.Discard, ""); err != nil {
		t.Fatal(err)
	}
}
