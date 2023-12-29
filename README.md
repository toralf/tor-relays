[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy public and private Tor bridges or Snowflake proxies

## Quick start

To setup a new Tor public bridge at an existing Debian system with the hostname _my_bridge_, do

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

1. configure the system, e.g. in `inventory/systems.yaml`:

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

The deployment is made by _Ansible_.

## Additional software

To deploy additional software, i.e. _quassel_, define something like this in the inventory:

```yaml
my_group:
  hosts:
    my_host:
      additional_ports:
        - "4242"
      additional_software:
        - "quassel-core"
```

The Ansible role (in [network.yaml](./playbooks/roles/setup/tasks/network.yaml))
configures an arbitrarily choosen ipv6 address for [this](./playbooks/roles/setup/tasks/network.yaml#L2) reason.
For that the secret _seed_local_ is needed to seed the PRNG.

## Metrics

Configure `metrics_port` to expose Tor metrics, e.g. by choosing a pseudo-random value:

```yaml
snowflake:
  vars:
    metrics_port: "{{ range(10000,32000) | random(seed=seed_local + ansible_facts.hostname + ansible_facts.default_ipv4.address + ansible_facts.default_ipv6.address) }}"
```

If a Prometheus server is configured (e.g. `prometheus_server: "1.2.3.4"` in _secrets/local.yaml_ or _inventory/all.yaml_)
then its ip address is configured to allow scraping metrics.
The value _targets_ (used in the Prometheus server config file) can be created by:

```bash
./site-info.yaml --tags metrics-port
cat ~/tmp/snowflake_metrics_port | sort | xargs -n 10 | sed -e 's,^,[",' -e 's,$,"],' -e 's, ,"\, ",g'
```

A _Prometheus node exporter_ is installed and configured to deliver metrics at `ipv4 address:9100` by defining:

```yaml
prometheus_node_exporter: true
```

If a Prometheus server ip defined then its ip address is configured to allow scraping metrics from port 9100.

For Grafana dashboards take a look [here](https://github.com/toralf/torutils/tree/main/dashboards).

## Misc

The scripts under [./bin](./bin) work for the Hetzner Cloud.
To create a new VPS with the hostname _my_bridge_ in the Hetzner project _my_project_, do:

```bash
hcloud context use my_project
./bin/create-server.sh my_bridge
```

The script [./bin/update-dns.sh](./bin/update-dns.sh) expects _unbound_ as a local DNS resolver,
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
