# Overview

Docker Compose for Plume Nitro Node

This setup is meant to be used with [central-proxy-docker](https://github.com/CryptoManufaktur-io/central-proxy-docker) for traefik
and Prometheus remote write; use `:ext-network.yml` in `COMPOSE_FILE` inside `.env` in that case.

If you want the RPC ports exposed locally, use `rpc-shared.yml` in `COMPOSE_FILE` inside `.env`.

## About the Dockerfile

The Dockerfile is adapted from the [official Plume Nitro repository](https://github.com/plumenetwork/plume-nitro), with key modifications:
- Git clone operations happen inside the Dockerfile, eliminating the need for manual repository cloning
- Files are copied from the git-cloned repository rather than the local filesystem

This approach allows you to build the Plume Nitro node with a single command without any prerequisites beyond Docker.

## Quick Start

The `./plume` script can be used as a quick-start:

`./plume install` brings in docker-ce, if you don't have Docker installed already.

`cp default.env .env`

`nano .env` and adjust variables as needed, particularly:
- `ETH_RPC_URL` - Required: URL for the Ethereum execution layer RPC endpoint
- `ETH_BEACON_RPC_URL` - Required: URL for the Ethereum consensus layer Beacon RPC endpoint
- Network configuration and other node settings

`./plume up`

## Software update

To update the software, run `./plume update` and then `./plume up`

## Required Configuration

For Plume to function correctly, you must provide the following in your `.env` file:

- `ETH_RPC_URL` - URL for an Ethereum execution layer RPC endpoint (e.g., from Geth, Erigon, etc.)
- `ETH_BEACON_RPC_URL` - URL for an Ethereum consensus layer Beacon RPC endpoint (e.g., from Lighthouse, Prysm, etc.)

Example:
```
ETH_RPC_URL=http://ethereum-execution:8545
ETH_BEACON_RPC_URL=http://ethereum-consensus:5052
```

You can use your own nodes or third-party providers for these endpoints.

## Customization

`custom.yml` is not tracked by git and can be used to override anything in the provided yml files. If you use it,
add it to `COMPOSE_FILE` in `.env`

## Version

Plume Docker uses a semver scheme.

This is Plume Docker v1.0.0
