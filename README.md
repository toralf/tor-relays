[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy Tor bridges

## Quick start

Setup a new Tor public bridge at Hetzner cloud:

1. clone this repo

   ```bash
   git clone https://github.com/toralf/tor-relays.git
   cd tor-relays
   ```

1. create the file `secrets/local.yaml`, eg.:

   ```yaml
   ---
   # https://github.com/nusenu/ContactInfo-Information-Sharing-Specification
   contact_info: "me@my.net"
   nickname_prefix: "nickneck"
   obfs4_port: 4711
   seed_or_port: "a-really-random-string"
   ```

1. choose the Hetzner project

   ```bash
   hcloud context list
   hcloud context use <your project>
   ```

1. create the VPS (hostname i.e.: _my_bridge_) in a Hetzner project (i.e. _my_project_):

   ```bash
   echo "my_bridge" | xargs -n 1 -P $(nproc) ./bin/create-server.sh
   ```

1. add the hostname to the host group `public`, i.e. in `inventory/foo.yaml`:

   ```yaml
   ---
   public:
     hosts:
       my_bridge:
         or_port: 8443 # overwrite the default "obfs4_port"
         obfs4_port: 4711 # overwrite the default created by using "seed_or_port"
   ```

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_bridge
   ```

1. get its state (maybe repeat after a while)

   ```bash
   ./site-info.yaml --limit my_bridge
   ```

1. for a private bridge get the bridge line

   ```bash
   ./site-bridgeline.yaml --limit my_bridge
   ```

## Details

The Tor bridges are deployed via an _Ansible_ role with a recent Debian OS.
The scripts under `./bin` works only for the Hetzner cloud,
_unbound_ is expected as the local DNS resolver and is expected to be configured like:

```config
include: "/etc/unbound/hetzner-private.conf"
include: "/etc/unbound/hetzner-public.conf"
```

To setup a private bridge, just replace `public` with `private` in the example above.
