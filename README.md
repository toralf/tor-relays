[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy public and private Tor bridges or Snowflake proxies

## Quick start

To setup a new Tor public bridge, i.e.: _my_bridge_, do

1. clone this repo

   ```bash
   git clone https://github.com/toralf/tor-relays.git
   cd tor-relays
   ```

1. create the file `secrets/local.yaml`, e.g.:

   ```yaml
   ---
   # Tor bridges
   contact_info: "me@my.net"
   nickname_prefix: "my_preferred_prefix"
   obfs4_port: 4711

   # Common
   seed_local: "a-really-random-string"
   ```

1. add the hostname _my_bridge_ to the Ansible host group `public`, e.g. into `inventory/systems.yaml`:

   ```yaml
   ---
   public:
     hosts:
       my_bridge:
         additional_ports:
           - "4242"
   ```

   For a private bridge replace `public` with `private`, similar applies for `snowflake`.
   The additional port is optionally and will be opened by the firewall too, i.e. it is the port for a _Quassel_ server.

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_bridge
   ```

## Details

The systems are deployed via an _Ansible_ role.
The task [network.yaml](./playbooks/roles/setup/tasks/network.yaml)
configures an arbitrarily choosen ipv6 address for [this](./playbooks/roles/setup/tasks/network.yaml#L2) reason.
The secret `seed_local` is needed to seed the PRNG for that.

The scripts under [bin](./bin) to create a VPS works works only for Hetzner.
To create a new VPS with the hostname _my_bridge_ in the Hetzner project _my_project_, do:

```bash
hcloud context use my_project
./bin/create-server.sh my_bridge
```

Get its state

```bash
./site-info.yaml --limit my_bridge
```

[update-dns.sh](./bin/update-dns.sh) expects _unbound_ as a local DNS resolver,
configured for each Hetzner project (== _context_) in this way:

```config
include: "/etc/unbound/hetzner-<project>.conf"
```

The file `secrets/local.yaml` could be a good place for the ip address of a Prometheus server:

```yaml
prometheus_server: "1.2.3.4"
```

If set then an iptabels rule is configured to route incoming TCP inbound packets to that address to the metrics port of localhost.
For Grafana dashboards take a look [here](https://github.com/toralf/torutils/tree/main/dashboards).
The Prometheus _targets_ config value e.g. for Snowflake can be created by:

```bash
 hcloud server list |
 grep -v NAME | awk '{ print $2 }' | sort | xargs | sed -e 's,^,[",' -e 's,$,:9999"],' -e 's, ,:9999"\, ",g'
```

## Links

https://bridges.torproject.org/

https://snowflake.torproject.org/

https://github.com/nusenu/ContactInfo-Information-Sharing-Specification
