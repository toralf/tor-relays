[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy public and private Tor bridges or Snowflake proxies

## Quick start

The deployment is made by an _Ansible_.
To setup a new Tor public bridge, i.e.: _my_bridge_,

1. clone this repo

   ```bash
   git clone https://github.com/toralf/tor-relays.git
   cd tor-relays
   ```

1. create (once) the file `secrets/local.yaml`, e.g.:

   ```yaml
   ---
   seed_local: "a-really-random-string"
   ```

1. configure the hostname _my_bridge_, e.g. in `inventory/systems.yaml`:

   ```yaml
   ---
   public:
     vars:
       contact_info: "me@my.net"
       nickname_prefix: "my_preferred_prefix"
       obfs4_port: 4711
     hosts:
       my_bridge:
   ```

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_bridge
   ```

1. get its states by

   ```bash
   ./site-info.yaml --limit my_bridge
   grep my_bridge ~/tmp/public_*
   ```

Replace _public_ with _private_ for a private Tor bridge or with _snowflake_ for the _Snowflake standlone proxy_.

## Details

By setting

```yaml
prometheus_node_exporter: true
```

for a host and defining the ip address of a Prometheus server
(e.g. `prometheus_server: "1.2.3.4"` in _secrets/local.yaml_ or _inventory/all.yaml_)
the _Prometheus node exporter_ is installed
and configured to deliver metrics at port 9100 of the ipv4 address of the host.
The Prometheus config value _targets_ can be created (i.e. for metrics port 9999) e.g. by:

```bash
./site-info.yaml --tags metrics-port
grep -h ":9999" ~/tmp/*_metrics_port | sort | xargs | sed -e 's,^,[",' -e 's,$,"],' -e 's, ,"\, ",g'
```

For Grafana dashboards take a look [here](https://github.com/toralf/torutils/tree/main/dashboards).
To deploy additional software, i.e. _quassel_,
define something like this in the inventory:

```yaml
my_group:
  hosts:
    my_host:
      additional_ports:
        - "4242"
      additional_software:
        - "quassel-core"
```

Ansible role ([network.yaml](./playbooks/roles/setup/tasks/network.yaml))
configures an arbitrarily choosen ipv6 address for [this](./playbooks/roles/setup/tasks/network.yaml#L2) reason.
For that the secret _seed_local_ is needed to seed the PRNG.

## Misc

The scripts under [bin](./bin) work for the Hetzner Cloud.
To create a new VPS with the hostname _my_bridge_ in the Hetzner project _my_project_, do:

```bash
hcloud context use my_project
./bin/create-server.sh my_bridge
```

The script [update-dns.sh](./bin/update-dns.sh) expects _unbound_ as a local DNS resolver,
configured for the appropriate Hetzner project (_hcloud_ uses the term _"context"_ for a project) like:

```config
include: "/etc/unbound/hetzner-<project>.conf"
```

## Links

- https://bridges.torproject.org
- https://snowflake.torproject.org
- https://www.ansible.com
- https://github.com/prometheus/node_exporter
- https://grafana.com
- https://github.com/NLnetLabs/unbound
