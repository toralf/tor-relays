[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

## Quick start

To setup a new Tor public bridge (i.e. with the hostname _my_bridge_), do

1. clone this repo

   ```bash
   git clone https://github.com/toralf/tor-relays.git
   cd ./tor-relays
   ```

1. run

   ```bash
   bash ./bin/base.sh
   ansible-playbook playbooks/ca.yaml -e @secrets/local.yaml --tags ca
   ```

   to create seeds, local dirs _~/tmp_ and _./secrets_ and a self-signed Root CA

1. add your bridge to the Ansible group _tor_:

   ```yaml
   ---
   tor:
     hosts:
       my_bridge:
   ```

   Take a look into [examples](./examples/) for an Ansible inventory using the Hetzner cloud.

1. deploy it

   ```bash
   ./site.yaml --limit my_bridge
   ```

1. inspect it:

   ```bash
   grep "my_bridge" ~/tmp/tor-relays/*
   ls ~/tmp/tor-relays/**/my_bridge*
   ```

1. enjoy it

## Details

The deployment is made by _Ansible_.
The Ansible role expects a `seed_address` value to change the ipv6 address at a Hetzner system
to a reliable randomized one (at IONOS a proposed one is displayed, but not set).
For Tor relays the DDoS solution of [torutils](https://github.com/toralf/torutils) used.
For Snowflake and NGinx instances a lightweight version of that ruleset is deployed.

### Additional software

To deploy additional software, configure it (i.e. for a _Quassel_ server) like:

```yaml
hosts:
  my_system:
    additional_ports:
      - "4242"
    additional_software:
      - "quassel-core"
```

### Compiling the Linux kernel, Tor, Lyrebird or Snowflake from source

The default branch is defined by the variable _<...>\_git_version_.
The variable _<...>\_patches_ might contain list of URIs to apply additional patches on the fly.

### Metrics

If a Prometheus server is configured (`prometheus_server`) then the inbound traffic from its ip to the
local metrics port is passed by a firewall allow rule ([code](./playbooks/roles/setup_common/tasks/firewall.yaml)).
The metrics port is pseudo-randomly choosen using _seed_metrics_.
Nginx is used to encrypt the data on transit ([code](./playbooks/roles/setup_common/tasks/metrics.yaml))
using the certificate of the self-signed Root CA ([code](./playbooks/roles/setup_common/tasks/ca.yaml)).
The Root CA key has to be put into the Prometheus config to enable scraping metrics via TLS.

```yaml
snowflake:
  vars:
    metrics_port: "{{ range(16000,60999) | random(seed=seed_metrics + inventory_hostname + ansible_facts.default_ipv4.address + ansible_facts.default_ipv6.address) }}"
    snowflake_metrics: true
    prometheus_server: "1.2.3.4
```

A _Prometheus node exporter_ is deployed if `node_metrics: true` is set.
For Prometheus config examples and Grafana dashboards take a look at [this](https://github.com/toralf/torutils/tree/main/dashboards) repository.

A static prometheus config could look like this:

```yaml
- job_name: "Nodes"
  metrics_path: "/metrics-node"
  scheme: https
  tls_config:
  ca_file: "RootCA.crt"
  file_sd_configs:
    - files:
        - "targets_nodes.yaml"
  params:
    collect[]:
      - conntrack
      - cpu
      - filesystem
      - loadavg
      - meminfo
      - netdev
      - netstat
      - vmstat

- job_name: "Tor-Snowflake-hx"
  metrics_path: "/metrics-snowflake"
  scheme: https
  tls_config:
  ca_file: "RootCA.crt"
  file_sd_configs:
    - files:
        - "targets_snowflake-hx.yaml"
  relabel_configs:
    - source_labels: [__address__]
      target_label: instance
      regex: "([^:]+).*"
      replacement: "${1}"
```

The _targets_ lines for the Prometheus config are put into _~/tmp/tor-relays/\*\-targets.yaml_.

### Misc

To create at Hetzner cloud a new VPS with the hostname _my_bridge_ under the project _my_project_, do:

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

The scripts under [./bin](./bin) work for the Hetzner Cloud API.

### Bisect a Linux kernel boot issue

With the inventory given in the [examples](./examples/) a _git bisect_ to identify e.g. a linux kernel issue is done basically by something like:

```bash
name=hn0d-intel-main-bp-cl-0
good=v6.16-rc2
bad=HEAD

cd ~/devel/tor-relays
./bin/create-server.sh ${name}

cd ~/devel/linux
git bisect start --no-checkout
git bisect good ${good}
git bisect bad ${bad}
git bisect run ~/devel/tor-relays/bin/bisect.sh ${name}
git bisect log
git bisect reset
```

## Links

- https://bridges.torproject.org
- https://snowflake.torproject.org
- https://www.ansible.com
- https://github.com/prometheus/node_exporter
- https://grafana.com
- https://github.com/NLnetLabs/unbound
