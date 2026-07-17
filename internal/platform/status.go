package platform

import (
	"os"
	"runtime"
	"time"

	"github.com/GoSense9/go9/internal/buildinfo"
)

type Status struct {
	Product              string  `json:"product"`
	Component            string  `json:"component"`
	Version              string  `json:"version"`
	Commit               string  `json:"commit"`
	BuildDate            string  `json:"build_date"`
	OS                   string  `json:"os"`
	Arch                 string  `json:"arch"`
	Hostname             string  `json:"hostname"`
	PID                  int     `json:"pid"`
	ProcessUptimeSeconds float64 `json:"process_uptime_seconds"`
}

type Provider struct{ started time.Time }

func NewProvider() *Provider { return &Provider{started: time.Now()} }
func (p *Provider) Status() (Status, error) {
	h, err := os.Hostname()
	if err != nil {
		h = "unknown"
	}
	return Status{Product: buildinfo.ProductName, Component: buildinfo.ComponentName, Version: buildinfo.Version, Commit: buildinfo.Commit, BuildDate: buildinfo.Date, OS: runtime.GOOS, Arch: runtime.GOARCH, Hostname: h, PID: os.Getpid(), ProcessUptimeSeconds: time.Since(p.started).Seconds()}, nil
}
