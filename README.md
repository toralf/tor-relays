[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy public and private Tor bridges or Snowflake proxies

## Quick start

Setup a new Tor public bridge, i.e.: _my_bridge_

1. clone this repo

   ```bash
   git clone https://github.com/toralf/tor-relays.git
   cd tor-relays
   ```

1. create the file `secrets/local.yaml`, e.g.:

   ```yaml
   ---
   contact_info: "me@my.net"
   nickname_prefix: "my_preferred_prefix"
   obfs4_port: 4711
   seed_local: "a-really-random-string"
   ```

1. add the hostname _my_bridge_ to the host group `public`, e.g. into `inventory/systems.yaml`:

   ```yaml
   ---
   public:
     hosts:
       my_bridge:
         additional_ports:
           - "4242"
   ```

   For a private bridge just replace `public` with `private`, similar for `snowflake`.
   The additional port is optionally and will be opened by the firewall too, i.e. it is the port for a _Quassel_ server.

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_bridge
   ```

For a snowflake bridge put its hostname into the `snowflake` group, secrets aren't needed.

## Details

The systems are deployed via an _Ansible_ role.
The scripts under [bin](./bin) to create a VPS works for Hetzner cloud system.
Same applies to one tasks in [network.yaml](./playbooks/roles/setup/tasks/network.yaml)
which configures a randomly choosen ipv6 address for a reason documented [here](./playbooks/roles/setup/tasks/network.yaml#L2).
The secret `seed_local` is needed to seed the RNG for that.
[update-dns.sh](./bin/update-dns.sh) expects _unbound_ as a local DNS resolver,
configured for each Hetzner project (== _context_) in this way:

```config
include: "/etc/unbound/hetzner-<project>.conf"
```

To create a new VPS with the hostname _my_bridge_ in the Hetzner project _my_project_, do:

```bash
hcloud context use my_project
./bin/create-server.sh my_bridge
```

Get its state

```bash
./site-info.yaml --limit my_bridge
```

To scrape metrics by a Prometheus server you've to defined its ip address in the secrets:

```yaml
prometheus_server: "1.2.3.4"
```

Its inbound requests will be routed to the localhost metrics port via DNAT.

For Grafana dashboards take a look [here](https://github.com/toralf/torutils/tree/main/dashboards).

## Links

https://bridges.torproject.org/

https://snowflake.torproject.org/

https://github.com/nusenu/ContactInfo-Information-Sharing-Specification
