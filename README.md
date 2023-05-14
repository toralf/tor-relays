[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy Tor bridges

## Quick start

Setup the new Tor public bridge _my_bridge_

1. clone this repo

   ```bash
   git clone https://github.com/toralf/tor-relays.git
   cd tor-relays
   ```

1. create the file `secrets/local.yaml`, eg.:

   ```yaml
   ---
   contact_info: "me@my.net"
   nickname_prefix: "nickneck"
   obfs4_port: 4711
   seed_or_port: "a-really-random-string"
   ```

1. add the hostname _my_bridge_ to the host group `public`, i.e. into `inventory/foo.yaml`:

   ```yaml
   ---
   public:
     hosts:
       my_bridge:
   ```

   To setup a private bridge, just replace `public` with `private` in the example.

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_bridge
   ```

## Details

The Tor bridges are deployed via an _Ansible_ role with a recent Debian OS.
The scripts under [bin](./bin) works only for the Hetzner cloud,
_unbound_ is expected as the local DNS resolver and configured in this way:

```config
include: "/etc/unbound/hetzner-private.conf"
include: "/etc/unbound/hetzner-public.conf"
```

To create a new VPS _my_bridge_ at Hetzner in the project _my_project_, do:

```bash
hcloud context use "my_project"
./bin/create-server.sh my_bridge
```

Get the state

```bash
./site-info.yaml --limit my_bridge
```

Get the bridge line

```bash
./site-bridgeline.yaml --limit my_bridge
```

## Links

https://bridges.torproject.org/

https://github.com/nusenu/ContactInfo-Information-Sharing-Specification
