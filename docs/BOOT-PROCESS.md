# Boot Process

In M0, `go9 --role=init` is a development supervisor, not production PID 1. It starts `control`, `console`, and `web` child processes, handles SIGINT/SIGTERM, and relies on the Go runtime/OS process APIs to reap children.
