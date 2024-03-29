[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy public and private Tor bridges or Snowflake proxies

## Quick start

To setup a new Tor public bridge at an existing recent Debian system (i.e. with the hostname _my_bridge_), do

1. clone this repo

   ```bash
   git clone https://github.com/toralf/tor-relays.git
   cd ./tor-relays
   ```

1. create seeds, e.g.:

   ```bash
   cat <<EOF >> secrets/local.yaml
   ---
   seed_address: "$(base64 < /dev/urandom | tr -d '+/=' | head -c 32)"
   seed_metrics: "$(base64 < /dev/urandom | tr -d '+/=' | head -c 32)"
   seed_obfs4: "$(base64 < /dev/urandom | tr -d '+/=' | head -c 32)"

   EOF
   ```

1. add _my_bridge_ to an inventory file and configure its obfs4 port (i.e. within `inventory/systems.yaml`):

   ```yaml
   ---
   public:
     hosts:
       my_bridge:
         obfs4_port: 4711
   ```

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_bridge
   ```

1. get its stats:

   ```bash
   ./site-info.yaml --limit my_bridge
   grep my_bridge ~/tmp/public_*
   ```

## Details

The deployment is made by _Ansible_.
Replace _public_ with _private_ or with _snowflake_ for a private Tor bridge of a _Snowflake standlone proxy_ respectively.
See the section [Metrics](#metrics) below how to configure a pseudo-random port for obfs4.
The firewall provides basic capabilities.
For DDoS prevention please take a look at the [torutils](https://github.com/toralf/torutils) repository.
The Ansible role uses `seed_address` to configure an random ipv6 address at a Hetzner systems or to display a proposed one (e.g.for IONOS).

### Additional software

To deploy additional software to your system, i.e. a _Quassel_ server, define it in the inventory, e.g. by:

```yaml
my_group:
  hosts:
    my_system:
      additional_ports:
        - "4242"
      additional_software:
        - "quassel-core"
```

### Compiling Tor + obfs4 proxy or Snowflake from source instead using the Debian packages

As default _HEAD_ (of branch _main_) is taken.
A dedicated branch can be defined by the variable _<...>\_git_version_.
Furthermore _<...>\_patches_ holds additional patches (referenced by an URL) which will be applied on top of the branch.

### Metrics

If a Prometheus server is configured (e.g. `prometheus_server: "1.2.3.4"`) then its ip is granted by a firewall rule to scrape metrics.
An Nginx is used to encrypt the metrics data transfer, by using a certificate from a self-signed CA.
This CA is presented to the Prometheus too to secure the TLS handshake.

A _Prometheus node exporter_ is installed by defining `prometheus_node_exporter: true`.
Configure a randomly choosen `metrics_port` (using `seed_metrics` similar to `seed_address`)
to expose metrics at https://_address_:_metrics_port_/metrics-_node|relay|snowflake_
(Prometheus Node exporter, Tor and Snowflake respectively), e.g.:

```yaml
snowflake:
  vars:
    metrics_port: "{{ range(16000,60999) | random(seed=seed_metrics + inventory_hostname + ansible_facts.default_ipv4.address + ansible_facts.default_ipv6.address) }}"
```

For appropriate Prometheus config examples and Grafana dashboards take a look at [this](https://github.com/toralf/torutils/tree/main/dashboards) repository.

### Misc

The value _targets_ (used in the Prometheus server config file) can be created e.g. by:

```bash
./site-info.yaml --tags metrics-port
sort ~/tmp/public_metrics_port | xargs -n 10 | sed -e 's,$,"],' -e 's, ,"\, ",g' -e 's,^,- targets: [",'
```

The scripts under [./bin](./bin) work for the Hetzner Cloud API only.

To create there a new VPS with the hostname _my_bridge_ in the project _my_project_, do:

```bash
hcloud context use my_project
./bin/create-server.sh my_bridge
```

The script [./bin/update-dns.sh](./bin/update-dns.sh) expects _unbound_ as a local DNS resolver,
configured for the appropriate project:

```config
include: "/etc/unbound/hetzner-<project>.conf"
```

(_hcloud_ uses the term _"context"_ for a project)

## Links

- https://bridges.torproject.org
- https://snowflake.torproject.org
- https://www.ansible.com
- https://github.com/prometheus/node_exporter
- https://grafana.com
- https://github.com/NLnetLabs/unbound
