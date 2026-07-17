package main

import (
	"context"
	"fmt"
	"github.com/GoSense9/go9/internal/bootstrap"
	"github.com/GoSense9/go9/internal/console"
	"github.com/GoSense9/go9/internal/control"
	"github.com/GoSense9/go9/internal/platform"
	"github.com/GoSense9/go9/internal/supervisor"
	"github.com/GoSense9/go9/internal/web"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
func run(args []string) error {
	cfg, err := bootstrap.Parse(args)
	if err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	sock := control.SocketPath(cfg.ControlSocket)
	switch cfg.Role {
	case bootstrap.RoleInit:
		exe, err := os.Executable()
		if err != nil {
			return err
		}
		return supervisor.New(exe, []supervisor.Process{{Role: "control", Args: []string{"--control-socket", sock}, Policy: supervisor.RestartAlways}, {Role: "console", Args: []string{"--control-socket", sock}, Policy: supervisor.RestartOnFailure}, {Role: "web", Args: []string{"--control-socket", sock, "--web-addr", cfg.WebAddr}, Policy: supervisor.RestartOnFailure}}).Run(ctx)
	case bootstrap.RoleControl:
		return control.NewServer(sock, platform.NewProvider()).Serve(ctx)
	case bootstrap.RoleConsole:
		return console.Run(ctx, os.Stdin, os.Stdout, sock)
	case bootstrap.RoleWeb:
		srv, err := web.New(cfg.WebAddr, sock)
		if err != nil {
			return err
		}
		return srv.Run(ctx)
	default:
		return fmt.Errorf("unsupported role %q", cfg.Role)
	}
}
