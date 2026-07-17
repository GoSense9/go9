package console

import "testing"

func TestParseCommand(t *testing.T) {
	cases := map[string]Command{"help": CmdHelp, "version": CmdVersion, "system status": CmdSystemStatus, " exit ": CmdExit, "rm -rf /": CmdUnknown}
	for in, want := range cases {
		if got := ParseCommand(in); got != want {
			t.Fatalf("%q got %v want %v", in, got, want)
		}
	}
}
