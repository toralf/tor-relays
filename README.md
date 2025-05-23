[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# Main Goal

Maintain Tor, Snowflake and Nginx instances using latest self-compiled/configured app/kernel versions.

## Quick start

To setup a new Tor public bridge (i.e. with the hostname _my_bridge_), do

1. clone this repo

   ```bash
   git clone https://github.com/toralf/tor-relays.git
   cd ./tor-relays
   ```

1. create:

   - seeds
   - local dirs _~/tmp_ and _./secrets_
   - and a self-signed Root CA

   ```bash
   bash ./bin/base.sh
   ansible-playbook playbooks/ca.yaml -e @secrets/local.yaml --tags ca
   ```

1. add your bridge to the inventory group _tor_:

   ```yaml
   ---
   tor:
     hosts:
       my_bridge:
   ```

   ([example](./examples/inventory.yaml) for a static Ansible inventory).

1. deploy it

   ```bash
   ./site.yaml --limit my_bridge
   ```

1. inspect it:

   ```bash
   grep "my_bridge" ~/tmp/*
   ```

1. enjoy it:

## Details

The deployment is made by _Ansible_.
See the section [Metrics](#metrics) below how to scrape runtime metrics.
The Ansible role expects a `seed_address` value to change the ipv6 address at a Hetzner system to a relyable randomized one
(at IONOS a proposed one is displayed, but not set).
For Tor servers the DDoS solution of [torutils](https://github.com/toralf/torutils) used.
For Tor bridges and Snowflake a lightweight version of that is used..

The _MyFamily_ value for Tor server is derived from the output of:

```bash
./site-info.yaml --tags wellknown --limit my_bridge
```

in the next run of the setup script:

```bash
./site.yaml --tags config --limit my_bridge
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

As default _HEAD_ (of the Git branch _main_) is taken.
A branch can be defined by the variable _<...>\_git_version_.
Furthermore _<...>\_patches_ is a list of URIs to fetch additional patches from (appleid on top of the branch).

### Metrics

If a Prometheus server is configured (`prometheus_server`) then inbound traffic from its ip to the
local metrics port is allowed by a firewall rule
([code](./playbooks/roles/setup_common/tasks/firewall.yaml)).
An Nginx is used to encrypt the metrics data transfer on transit
([code](./playbooks/roles/setup_common/tasks/metrics.yaml))
using the certificate of a self-signed Root CA ([code](./playbooks/roles/setup_common/tasks/ca.yaml)).
This Root CA key has to be put into the Prometheus config to enable the TLS traffic
([example](https://github.com/toralf/torutils/tree/main/dashboards)).
Configure a `metrics_port` to expose several kind of metrics at
https://_address_:_metrics_port_/metrics-_node|snowflake|tor_
(i.e. the metrics port is pseudo-randomly choosen using _seed_metrics_):

```yaml
snowflake:
  vars:
    metrics_port: "{{ range(16000,60999) | random(seed=seed_metrics + inventory_hostname + ansible_facts.default_ipv4.address + ansible_facts.default_ipv6.address) }}"
    snowflake_metrics: true
    prometheus_server: "1.2.3.4
```

In addition the _Prometheus node exporter_ is deployed by: `node_metrics: true`.
For more Prometheus config examples and Grafana dashboards take a look at [this](https://github.com/toralf/torutils/tree/main/dashboards) repository.

My static prometheus config contains something like:

```yaml
- job_name: "Tor-Snowflake-hx"
   metrics_path: '/metrics-snowflake'
   scheme: https
   tls_config:
   ca_file: 'RootCA.crt'
   file_sd_configs:
   - files:
      - 'targets_snowflake-hx.yaml'
   relabel_configs:
   - source_labels: [__address__]
      target_label: instance
      regex: "([^:]+).*"
      replacement: '${1}'
...
```

The _targets_ line for the static Prometheus targets file is created by:

```bash
./site-info.yaml --tags metrics --limit my_bridge

grep my_bridge ~/tmp/all_metrics_port
```

### Misc

To create at Hetzner a new VPS with the hostname _my_bridge_ in the project _my_project_, do:

```bash
hcloud context use my_project
./bin/create-server.sh my_bridge
```

The script [./bin/update-dns.sh](./bin/update-dns.sh) expects _unbound_ as a local DNS resolve and _openrc_ as the init system,
configured for the appropriate project:

```config
include: "/etc/unbound/hetzner-<project>.conf"
```

(_hcloud_ uses the term _"context"_ for a project)

The scripts under [./bin](./bin) work only for the Hetzner Cloud API.

## Links

- https://bridges.torproject.org
- https://snowflake.torproject.org
- https://www.ansible.com
- https://github.com/prometheus/node_exporter
- https://grafana.com
- https://github.com/NLnetLabs/unbound
