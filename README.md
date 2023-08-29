[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy public and private Tor bridges or Snowflake

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
   nickname_prefix: "my_preferred_prefix"
   obfs4_port: 4711
   seed_local: "a-really-random-string"
   ```

1. add the hostname _my_bridge_ to the host group `public`, i.e. into `inventory/systems.yaml`:

   ```yaml
   ---
   public:
     hosts:
       my_bridge:
         additional_ports:
           - "4242"
   ```

   For a private bridge just replace `public` with `private`, similar for `snowflake`.
   In the example the (optional) additional port to be opened by a firewall is needed for a _Quassel_ server.

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_bridge
   ```

For a snowflake bridge put its hostname into the `snowflake` group, no secrets (step 2) are needed.

## Details

The systems are deployed via an _Ansible_ role using a recent Debian OS.
The scripts under [bin](./bin) to create the VPS works for the Hetzner cloud only.
Same applies to the Ansible task [network.yaml](./playbooks/roles/setup/tasks/network.yaml).
That task configures a randomly choosen ipv6 address (global scope)
from the given /64 subnet and preroutes all incoming TCPv6 connections to it.
[update-dns.sh](./bin/update-dns.sh) expects _unbound_ as a local DNS resolver,
configured for each Hetzner project in this way:

```config
include: "/etc/unbound/hetzner-<project>.conf"
...
```

To create a new VPS _my_bridge_ in the Hetzner project _my_project_, do:

```bash
hcloud context use "my_project"
./bin/create-server.sh my_bridge
```

Get its state

```bash
./site-info.yaml --limit my_bridge
```

All other output goes to a tmp directory defined by the variable `tmp_dir` in [all.yaml](./inventory/group_vars/all.yaml).

## Links

https://bridges.torproject.org/

https://snowflake.torproject.org/

https://github.com/nusenu/ContactInfo-Information-Sharing-Specification
