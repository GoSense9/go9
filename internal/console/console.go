package console

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"github.com/GoSense9/go9/internal/buildinfo"
	"github.com/GoSense9/go9/internal/control"
)

const Prompt = "go9> "

type Command int

const (
	CmdUnknown Command = iota
	CmdHelp
	CmdVersion
	CmdSystemStatus
	CmdExit
)

func ParseCommand(s string) Command {
	switch strings.Join(strings.Fields(s), " ") {
	case "help":
		return CmdHelp
	case "version":
		return CmdVersion
	case "system status":
		return CmdSystemStatus
	case "exit", "quit":
		return CmdExit
	default:
		return CmdUnknown
	}
}
func Run(ctx context.Context, in io.Reader, out io.Writer, sock string) error {
	lines := make(chan string)
	errs := make(chan error, 1)
	go scanLines(in, lines, errs)
	for {
		fmt.Fprint(out, Prompt)
		select {
		case <-ctx.Done():
			return ctx.Err()
		case err := <-errs:
			return err
		case line := <-lines:
			switch ParseCommand(line) {
			case CmdHelp:
				fmt.Fprintln(out, "commands: help, version, system status, exit")
			case CmdVersion:
				fmt.Fprintf(out, "%s %s\n", buildinfo.ComponentName, buildinfo.Version)
			case CmdSystemStatus:
				resp, err := control.Call(ctx, sock, "system.status")
				if err != nil {
					fmt.Fprintln(out, "error:", err)
					break
				}
				b, _ := json.MarshalIndent(resp.Result, "", "  ")
				fmt.Fprintln(out, string(b))
			case CmdExit:
				return nil
			default:
				fmt.Fprintln(out, "unknown command; type help")
			}
		}
	}
}

func scanLines(in io.Reader, lines chan<- string, errs chan<- error) {
	sc := bufio.NewScanner(in)
	for sc.Scan() {
		lines <- sc.Text()
	}
	errs <- sc.Err()
}
