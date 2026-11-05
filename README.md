[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# Why

This repo focuses on sharing ideas for maintaining Tor systems with Ansible.

## Quick start

Setup a new Tor private bridge (i.e. with the hostname _my_bridge_):

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

   to create seeds, local dirs (e.g. _~/tmp_ and _./secrets_() and a self-signed Root CA.

1. add your Tor system to the Ansible inventory, i.e. as _my_relay_.
   Take a look into [examples](./examples/).

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_relay
   ```

1. inspect it:

   ```bash
   tail -v ~/tmp/tor-relays/*
   ls ~/tmp/tor-relays/**/my_relay*
   ```

1. enjoy it

## Details

The configuration is made by _Ansible_.
The creation of a relay has to be made before.
For Hetzner there're appropriate scripts in _./bin_.
The Ansible role uses `seed_address` to change the IPv6 address at a Hetzner system
to a pseudo-randomized one. At IONOS a proposed IPv6 one is printed out, but not set.
For Tor relays the DDoS prevention solution from [torutils](https://github.com/toralf/torutils) is used.
For Snowflake and NGinx instances a lightweight version of that ruleset is deployed.

### Additional software

To deploy additional software, configure it (i.e. for a _Quassel_ server) like:

```yaml
hosts:
  my_system:
    ingress_ports:
      - "4242"
    additional_software:
      - quassel-core
```

### Compiling the Linux kernel, Tor, Lyrebird and Snowflake from source

The git branch is defined by the variable _<...>\_git_version_.
The list _<...>\_patches_ can be used to apply additional patches on top.

### Metrics

If a Prometheus is configured then the inbound traffic from Prometheus to the
metrics port of the deployed system is opened in the firewall ([code](./playbooks/roles/setup_common/tasks/firewall-nft.yaml)).
The metrics port is pseudo-randomized, _seed_metrics_ is expected to be setfor that.
An Nginx is used to encrypt the data on transit ([code](./playbooks/roles/setup_common/tasks/nginx.yaml)),
secured by the self-signed Root CA ([code](./playbooks/roles/ca/tasks/main.yaml)).
The Root CA key has to be configured in the Prometheus config scrape metrics over a TLS connection:

```yaml
vars:
  metrics_port: "{{ range(1024,65535) | random(seed=seed_metrics + inventory_hostname + ansible_facts.default_ipv4.address + ansible_facts.default_ipv6.address) }}"
  prometheus_server_v4: "1.2.3.4"
```

A _Prometheus node exporter_ is deployed if `node_metrics: true` is set.
For Prometheus config examples and Grafana dashboards take a look at [this](https://github.com/toralf/torutils/tree/main/dashboards) repository.
A Prometheus config could look like this:

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

The input for the Prometheus config can be created by ([targets.yaml](./playbooks/roles/setup_common/tasks/targets.yaml)).

### Misc

To create a new VPS in the Hetzner cloud with the hostname _my_bridge_ in the project  _my_project_, do:

```bash
hcloud context use my_project
./bin/create-server.sh my_bridge
```

The script [update-dns.sh](./bin/update-dns.sh) expects _unbound_ as a local DNS resolver and _OpenRC_ as the init system,
configured for the appropriate project:

```config
include: "/etc/unbound/hetzner-<project>.conf"
```

(_hcloud_ uses the term _"context"_ for a project)

The scripts under [./bin](./bin) work for the Hetzner Cloud API only.

### Bisect a Linux kernel boot issue

With the inventory given in the [examples](./examples/) a _git bisect_ to identify e.g. a linux kernel issue is done basically by something like:

```bash
name=foo
good=v6.16-rc2
bad=HEAD

./bin/create-server.sh ${name}
./site-test-kernel.yaml --limit ${name} --skip-tags kernel-build,delete

cd ~/devel/linux
git bisect start --no-checkout
git bisect good ${good}
git bisect bad ${bad}
git bisect run ./bin/bisect.sh ${name}
git bisect log
git bisect reset
```

## Resources

If you have a bigger inventory then increase your ulimits, e.g.

```bash
ulimit -S -n 4096
```

## Links

- https://bridges.torproject.org
- https://snowflake.torproject.org
- https://www.ansible.com
- https://github.com/prometheus/node_exporter
- https://grafana.com
- https://github.com/NLnetLabs/unbound
