# Overview

Docker Compose for Plume Nitro Node
https://docs.plume.org/plume/developers/how-to-guides/how-to-run-a-node

This setup is meant to be used with [central-proxy-docker](https://github.com/CryptoManufaktur-io/central-proxy-docker) for traefik
and Prometheus remote write; use `:ext-network.yml` in `COMPOSE_FILE` inside `.env` in that case.

If you want the RPC ports exposed locally, use `rpc-shared.yml` in `COMPOSE_FILE` inside `.env`.

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

## Checking Sync Status

To verify your node is synced with the public Wemix network:

```bash
bash scripts/check_sync.sh
```

This script compares your local node's latest block against the public Plume RPC endpoint (`https://rpc.plume.org`). It will report:
- ✅ Node is in sync (height and hash match)
- ⚠️ Heights differ - still syncing
- ❌ Heights match but hashes differ - possible reorg or divergence

Defaults used by the sync check:
- Public RPC: `https://rpc.plume.org`
- Local RPC: `http://127.0.0.1:${RPC_PORT}` (from `.env`, default `8545`)
- Compose service (wrapper): `consensus` (when using `./ethd check-sync`)

You can also run:

```bash
./ethd check-sync
```

## Version

Plume Docker uses a semver scheme.

This is Plume Docker v1.0.0
