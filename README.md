[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy public and private Tor bridges or Snowflake proxies

## Quick start

To setup a new Tor public bridge at an existing recent Debian system (i.e. with the hostname _my_bridge_), do

1. clone this repo

   ```bash
   git clone https://github.com/toralf/tor-relays.git
   cd ./tor-relays
   ```

1. create a seed, e.g.:

   ```bash
   cat <<EOF >> secrets/local.yaml
   ---
   seed_address: "$(dd if=/dev/random | base64 | cut -c 1-32 | head -n 1)"

   EOF
   ```

   or run something similar, e.g. `pwgen 32`.

1. add the system to the inventory and configure an obfs4 port, i.e. in `inventory/systems.yaml`:

   ```yaml
   ---
   public:
     vars:
       obfs4_port: 4711
     hosts:
       my_bridge:
   ```

So the section [Metrics](#metrics) below for using a pseudo-random port for obfs4 analogous to a metrics port.

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_bridge
   ```

1. get stats:

   ```bash
   ./site-info.yaml --limit my_bridge
   grep my_bridge ~/tmp/public_*
   ```

Replace _public_ with _private_ for a private Tor bridge or with _snowflake_ for the _Snowflake standlone proxy_.

## Details

The deployment is made by _Ansible_.
The firewall does not contains DDoS capabilities.
For that please take a look at the [torutils](https://github.com/toralf/torutils) repository.
The Ansible role uses `seed_address` to
configure an random ipv6 address for [this](./playbooks/roles/setup/tasks/network.yaml#L2) reason.

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

### Snowflake patching

As default _HEAD_ (of _main_) is deployed. With a host group _my_sf_group_ like

```yaml
my_sf_group:
  vars:
    snowflake_git_version: "<commit-ish>"
    snowflake_patches:
      - https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/-/merge_requests/225.diff
  hosts:
    my_patched_sf:
```

and adding it to the main Snowflake group:

```yaml
snowflake:
  vars:
  ...
  hosts:
  ...
  children:
    my_sf_group:
```

this can be changed (i.e. for the system _my_patched_sf_).
Similar applies to the variable _snowflake_patches_.

### Metrics

If a Prometheus server is configured (e.g. `prometheus_server: "1.2.3.4"`)
then its ip address is configured to allow scraping Tor metrics.
Configure `metrics_port` to expose Prometheus Node exporter, Tor and Snowflake metrics at `https://<ipv4 address>:<metrics_port>/metrics-<node|relay|snowflake>`respectively.

```yaml
snowflake:
  vars:
    metrics_port: "{{ range(16000,60999) | random(seed=seed_metrics + inventory_hostname + ansible_facts.default_ipv4.address + ansible_facts.default_ipv6.address) }}"
```

Configure an appropriate `seed_metrics` similar to `seed_address`.
An NGinx is used as a reverse proxy to encrypt the metrics data on transit.
The firewall allows only the Prometheus server to scrape metrics.
No HTTP Basic Auth is therefore needed.
A _Prometheus node exporter_ is installed by defining:

```yaml
prometheus_node_exporter: true
```

A Prometheus config would contain somethin like:

```yaml
  - job_name: "Tor-Bridge-Public"
    scheme: https
    tls_config:
      insecure_skip_verify: true
    metrics_path: "/metrics-relay"
    static_configs:
      - targets: ["a:12345", ...]
    relabel_configs:
      - source_labels: [__address__]
        regex: '(.*):(.*)'
        replacement: '${1}'
        target_label: instance
```

For Grafana dashboards take a look [here](https://github.com/toralf/torutils/tree/main/dashboards).

### Misc

The value _targets_ (used in the Prometheus server config file) can be created e.g. by:

```bash
./site-info.yaml --tags metrics-port
sort ~/tmp/public_metrics_port | xargs -n 10 | sed -e 's,$,"],' -e 's, ,"\, ",g' -e 's,^,- targets: [",'
```

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
