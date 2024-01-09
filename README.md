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

1. add the system to the inventory and configure at least an obfs4 port, i.e. in `inventory/systems.yaml`:

   ```yaml
   ---
   public:
     vars:
       obfs4_port: 4711
     hosts:
       my_bridge:
   ```

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_bridge
   ```

1. get its states:

   ```bash
   ./site-info.yaml --limit my_bridge
   grep my_bridge ~/tmp/public_*
   ```

Replace _public_ with _private_ for a private Tor bridge or with _snowflake_ for the _Snowflake standlone proxy_.

## Details

The deployment is made by _Ansible_.

### IPv6

The Ansible role (in [network.yaml](./playbooks/roles/setup/tasks/network.yaml)) uses `seed_addrees` to
configure an random ipv6 address (for [this](./playbooks/roles/setup/tasks/network.yaml#L2) reason).

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

Configure `metrics_port` to expose Tor or Snowflake metrics at `ipv4 address:metrics_port`.
IMO a pseudo-random value (instead the default `9999` for Snowflake or `9052`` for Tor respectively) should be preferrred, e.g. by:

```yaml
snowflake:
  vars:
    metrics_port: "{{ range(10000,32000) | random(seed=seed_address + ansible_facts.hostname + ansible_facts.default_ipv4.address + ansible_facts.default_ipv6.address) }}"
```

If a Prometheus server is configured (e.g. `prometheus_server: "1.2.3.4"`)
then its ip address is configured to allow scraping Tor metrics.

A _Prometheus node exporter_ is installed and configured at `ipv4 address:9100` by defining:

```yaml
prometheus_node_exporter: true
```

If a Prometheus server ip defined then its ip address is configured to allow scraping node metrics.

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
