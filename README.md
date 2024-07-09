[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy Tor relays or Snowflake

## Quick start

To setup a new Tor public bridge at an existing recent Debian system (i.e. with the hostname _my_bridge_), do

1. clone this repo

   ```bash
   git clone https://github.com/toralf/tor-relays.git
   cd ./tor-relays
   ```

1. create a seed (only once needed, please keep it secret):

   ```bash
   cat <<EOF >>secrets/local.yaml
   ---
   seed_address: "$(base64 < /dev/urandom | tr -d '+/=' | head -c 32)"

   EOF

   chmod 400 secrets/local.yaml
   ```

1. add your bridge, i.e. _my_bridge_, to the group, i.e. _tor_, to a YAML file under [./inventory](./inventory/):

   ```yaml
   ---
   tor:
     hosts:
       my_bridge:
         bridge_distribution: "any"
         tor_port: 12345
   ```

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_bridge
   ```

1. get its data:

   ```bash
   ./site-info.yaml --limit my_bridge
   grep my_bridge ~/tmp/*
   ```

## Details

The deployment is made by _Ansible_.
See the section [Metrics](#metrics) below how to scrape runtime metrics.
The Ansible role expects a `seed_address` value to change the ipv6 address at a Hetzner system to a relyable randomized one
(at IONOS a proposed one is displayed, but not set).
For Tor servers the DDoS solution of [torutils](https://github.com/toralf/torutils) used.
For Tor bridges and Snowflake a lightweight version of that is used..

The _MyFamily_ value for Tor server is derived from the output of:

```bash
./site-info.yaml --tags wellknown
```

in the next run of the setup script:

```bash
./site-setup.yaml --tags config
```

(look [here](./playbooks/roles/setup_tor/vars/main.yaml.) for details).

### Additional software

To deploy additional software, define (i.e. for a _Quassel_ server) it like:

```yaml
hosts:
  my_system:
    additional_ports:
      - "4242"
    additional_software:
      - "quassel-core"
```

### Compiling the Linux kernel, Tor, Lyrebird or Snowflake from source

As default _HEAD_ (of branch _main_) is taken.
A dedicated branch can be defined by the variable _<...>\_git_version_.
Furthermore _<...>\_patches_ can provide additional patches (as URLs) to be applied on top.

### Metrics

If a Prometheus server is configured (e.g. `prometheus_server: "1.2.3.4"`) then inbound traffic from its ip to the local metrics port is allowed by a firewall rule
([code](./playbooks/roles/setup/tasks/firewall.yaml)).
An Nginx is used to encrypt the metrics data transfer on transit ([code](./playbooks/roles/setup/tasks/metrics.yaml)).
using the certificate of the self-signed CA ([code](./playbooks/roles/setup/tasks/ca.yaml)).
This CA key has then to be presented to the Prometheus to enable the TLS traffic ([example](https://github.com/toralf/torutils/tree/main/dashboards)).

Configure a randomly choosen `metrics_port` (create `seed_metrics` as before `seed_address`)
to expose metrics at https://_address_:_metrics_port_/metrics-_node|snowflake|tor_:

```yaml
snowflake:
  vars:
    metrics_port: "{{ range(16000,60999) | random(seed=seed_metrics + inventory_hostname + ansible_facts.default_ipv4.address + ansible_facts.default_ipv6.address) }}"
    snowflake_metrics: true
```

A _Prometheus node exporter_ is deployed by defining `prometheus_node_exporter: true`.

For more Prometheus config examples and Grafana dashboards take a look at [this](https://github.com/toralf/torutils/tree/main/dashboards) repository.

### Misc

The value _targets_ (used in the Prometheus server config file) can be created e.g. by:

```bash
./site-info.yaml --tags metrics-port
sort ~/tmp/*_metrics_port | xargs -n 10 | sed -e 's,$,"],' -e 's, ,"\, ",g' -e 's,^,- targets: [",'
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
