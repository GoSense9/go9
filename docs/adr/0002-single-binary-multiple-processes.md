# ADR 0002: single binary multiple processes

## Status

Accepted for M0.

## Context

GoSense9 targets a hardened FreeBSD-family operating environment with a small Go control plane named internally as `go9`.

## Decision

Record the M0 decision and keep implementation minimal, auditable, and defer broader platform capabilities to later milestones.

## Consequences

The initial scaffold favors process separation, local APIs, and documentation over feature breadth.
