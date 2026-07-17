package bootstrap

import "flag"

type Role string

const (
	RoleInit    Role = "init"
	RoleControl Role = "control"
	RoleConsole Role = "console"
	RoleWeb     Role = "web"
)

type Config struct {
	Role          Role
	ControlSocket string
	WebAddr       string
}

func Parse(args []string) (Config, error) {
	fs := flag.NewFlagSet("go9", flag.ContinueOnError)
	role := fs.String("role", "console", "process role: init, control, console, or web")
	sock := fs.String("control-socket", "", "control socket path")
	web := fs.String("web-addr", ":8080", "web listen address")
	if err := fs.Parse(args); err != nil {
		return Config{}, err
	}
	r := Role(*role)
	switch r {
	case RoleInit, RoleControl, RoleConsole, RoleWeb:
		return Config{Role: r, ControlSocket: *sock, WebAddr: *web}, nil
	default:
		return Config{}, flag.ErrHelp
	}
}
