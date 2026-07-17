package web

import (
	"context"
	"embed"
	"encoding/json"
	"github.com/GoSense9/go9/internal/control"
	"html/template"
	"net/http"
)

//go:embed templates/* static/*
var content embed.FS

type Server struct {
	addr, sock string
	tmpl       *template.Template
}

func New(addr, sock string) (*Server, error) {
	t, err := template.ParseFS(content, "templates/*.html")
	if err != nil {
		return nil, err
	}
	return &Server{addr: addr, sock: sock, tmpl: t}, nil
}
func (s *Server) Run(ctx context.Context) error {
	mux := http.NewServeMux()
	mux.Handle("/static/", http.FileServer(http.FS(content)))
	mux.HandleFunc("/", s.dashboard)
	mux.HandleFunc("/system/status", s.status)
	srv := &http.Server{Addr: s.addr, Handler: mux}
	go func() { <-ctx.Done(); _ = srv.Shutdown(context.Background()) }()
	err := srv.ListenAndServe()
	if err == http.ErrServerClosed {
		return nil
	}
	return err
}
func (s *Server) dashboard(w http.ResponseWriter, r *http.Request) {
	_ = s.tmpl.ExecuteTemplate(w, "dashboard.html", nil)
}
func (s *Server) status(w http.ResponseWriter, r *http.Request) {
	resp, err := control.Call(r.Context(), s.sock, "system.status")
	data := map[string]any{"Error": err, "Status": resp.Result}
	if m, ok := resp.Result.(map[string]any); ok {
		data["Status"] = m
	} else {
		var m map[string]any
		b, _ := json.Marshal(resp.Result)
		_ = json.Unmarshal(b, &m)
		data["Status"] = m
	}
	_ = s.tmpl.ExecuteTemplate(w, "status.html", data)
}
