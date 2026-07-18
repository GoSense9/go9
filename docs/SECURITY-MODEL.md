# Security Model

M0 uses least-privilege process separation as a design direction. The init role supervises only and does not run the HTTP server. The console is not a Unix shell and never executes arbitrary commands. The web role reads system status through the local Control API instead of privileged host inspection.

The Control API listens on a Unix socket at `/run/go9/control.sock` by default. The socket directory is created with mode `0700`, the socket is chmodded to `0600`, and startup refuses to replace regular files, directories, or symlinks at the socket path.
