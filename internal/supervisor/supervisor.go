package supervisor

import (
	"context"
	"os"
	"os/exec"
	"sync"
	"time"
)

type RestartPolicy int

const (
	RestartNever RestartPolicy = iota
	RestartOnFailure
	RestartAlways
)

type Process struct {
	Role   string
	Args   []string
	Policy RestartPolicy
}
type Supervisor struct {
	exe   string
	procs []Process
}

func New(exe string, ps []Process) *Supervisor { return &Supervisor{exe: exe, procs: ps} }
func ShouldRestart(p RestartPolicy, err error) bool {
	if p == RestartAlways {
		return true
	}
	if p == RestartOnFailure && err != nil {
		return true
	}
	return false
}
func (s *Supervisor) Run(ctx context.Context) error {
	var wg sync.WaitGroup
	for _, p := range s.procs {
		p := p
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				args := append([]string{"--role=" + p.Role}, p.Args...)
				cmd := exec.CommandContext(ctx, s.exe, args...)
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				cmd.Stdin = os.Stdin
				err := cmd.Run()
				if ctx.Err() != nil || !ShouldRestart(p.Policy, err) {
					return
				}
				time.Sleep(time.Second)
			}
		}()
	}
	<-ctx.Done()
	wg.Wait()
	return nil
}
