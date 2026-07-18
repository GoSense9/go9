package control

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"time"

	"github.com/GoSense9/go9/internal/platform"
)

const DefaultSocketPath = "/run/go9/control.sock"
const EnvSocketPath = "GO9_CONTROL_SOCKET"

type Request struct {
	Operation string `json:"operation"`
}
type Response struct {
	OK     bool   `json:"ok"`
	Result any    `json:"result,omitempty"`
	Error  string `json:"error,omitempty"`
}
type Server struct {
	sock     string
	provider *platform.Provider
	ln       net.Listener
}

func SocketPath(flag string) string {
	if flag != "" {
		return flag
	}
	if e := os.Getenv(EnvSocketPath); e != "" {
		return e
	}
	return DefaultSocketPath
}
func NewServer(sock string, p *platform.Provider) *Server { return &Server{sock: sock, provider: p} }
func (s *Server) Listen() error {
	if err := os.MkdirAll(filepath.Dir(s.sock), 0700); err != nil {
		return err
	}
	if err := os.Chmod(filepath.Dir(s.sock), 0700); err != nil {
		return err
	}
	if info, err := os.Lstat(s.sock); err == nil {
		if info.Mode().Type() != os.ModeSocket {
			return fmt.Errorf("refusing to replace non-socket control path %s", s.sock)
		}
		if err := os.Remove(s.sock); err != nil {
			return err
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	ln, err := net.Listen("unix", s.sock)
	if err != nil {
		return err
	}
	if err := os.Chmod(s.sock, 0600); err != nil {
		_ = ln.Close()
		_ = os.Remove(s.sock)
		return err
	}
	s.ln = ln
	return nil
}
func (s *Server) Serve(ctx context.Context) error {
	if s.ln == nil {
		if err := s.Listen(); err != nil {
			return err
		}
	}
	go func() { <-ctx.Done(); _ = s.ln.Close(); _ = os.Remove(s.sock) }()
	for {
		c, err := s.ln.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
		go s.handle(c)
	}
}
func (s *Server) handle(c net.Conn) {
	defer c.Close()
	var req Request
	if err := json.NewDecoder(c).Decode(&req); err != nil {
		write(c, Response{OK: false, Error: "invalid request"})
		return
	}
	resp := s.Handle(req)
	write(c, resp)
}
func (s *Server) Handle(req Request) Response {
	switch req.Operation {
	case "system.status":
		st, err := s.provider.Status()
		if err != nil {
			return Response{OK: false, Error: err.Error()}
		}
		return Response{OK: true, Result: st}
	default:
		return Response{OK: false, Error: fmt.Sprintf("unknown operation %q", req.Operation)}
	}
}
func write(c net.Conn, r Response) { _ = json.NewEncoder(c).Encode(r) }
func Call(ctx context.Context, sock, op string) (Response, error) {
	var d net.Dialer
	c, err := d.DialContext(ctx, "unix", sock)
	if err != nil {
		return Response{}, err
	}
	defer c.Close()
	if err := json.NewEncoder(c).Encode(Request{Operation: op}); err != nil {
		return Response{}, err
	}
	_ = c.SetReadDeadline(time.Now().Add(5 * time.Second))
	var resp Response
	if err := json.NewDecoder(bufio.NewReader(c)).Decode(&resp); err != nil {
		return Response{}, err
	}
	if !resp.OK {
		if resp.Error != "" {
			return resp, errors.New(resp.Error)
		}
		return resp, errors.New("control request failed")
	}
	return resp, nil
}
