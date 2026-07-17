# Security Model

M0 uses least-privilege process separation as a design direction. The init role supervises only and does not run the HTTP server. The console is not a Unix shell and never executes arbitrary commands. The web role reads system status through the local Control API instead of privileged host inspection.
