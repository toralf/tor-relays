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
   ```

   For a private bridge replace `public` with `private`, similar applies for `snowflake`.

1. deploy it

   ```bash
   ./site-setup.yaml --limit my_bridge
   ```

## Details

The systems are deployed via an _Ansible_ role.
The task [network.yaml](./playbooks/roles/setup/tasks/network.yaml)
configures an arbitrarily choosen ipv6 address for [this](./playbooks/roles/setup/tasks/network.yaml#L2) reason.
The secret `seed_local` is needed to seed the PRNG for that.

The scripts under [bin](./bin) to create a VPS works only for Hetzner.
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
configured for each Hetzner project (_hcloud_ uses the term _context_ for a project) in this way:

```config
include: "/etc/unbound/hetzner-<project>.conf"
```

The file `secrets/local.yaml` would be a good place for the ip address of a Prometheus server, if used:

```yaml
prometheus_server: "1.2.3.4"
```

If this is and `metrics_port` is defined, e.g.:

```yaml
public:
  vars:
    metrics_port: 9052
  hosts:
```

then both the service and the network filter is configured
to allow scraping metrics.
For Grafana dashboards take a look [here](https://github.com/toralf/torutils/tree/main/dashboards).
The Prometheus config value _targets_ can be created i.e. for metrics port 9999 by:

```bash
./site-info.yaml --tags metrics-port
grep -h ":9999" ~/tmp/*_metrics_port | sort | xargs | sed -e 's,^,[",' -e 's,$,"],' -e 's, ,"\, ",g'
```

To deploy additional software, i.e. _quassel_,
define something like this in your inventory:

```yaml
my_group:
  hosts:
    my_host:
      additional_ports:
        - "4242"
      additional_software:
        - "quassel-core"
```

By setting

```yaml
prometheus_node_exporter: true
```

for a host the node exporter is installed and configured to deliver metrics at the ipv4 address at port 9100.

## Links

https://bridges.torproject.org/

https://snowflake.torproject.org/

https://github.com/nusenu/ContactInfo-Information-Sharing-Specification
