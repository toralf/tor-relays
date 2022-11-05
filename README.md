[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy Tor bridges

## Quick start

Setup a new Tor public bridge within the Hetzner cloud:

1. clone this repo

    ```bash
    git clone https://github.com/toralf/tor-relays.git
    cd tor-relays
    ```

1. create the file `secrets/local.yaml`, eg.:

    ```yaml
    ---
    # https://github.com/nusenu/ContactInfo-Information-Sharing-Specification
    contact_info: "me@my.net"
    nickname_prefix: "nickneck"
    obfs4_port: 4711
    seed_or_port: "a-really-random-string"
    ```

1. create the VPS (hostname i.e.: _my_bridge_) in a Hetzner project (i.e. _my_project_), eg.:

    ```bash
    ./bin/create-server.sh my_project my_bridge
    ```

1. add the hostname to the host group `public`, eg. in `inventory/foo.yaml`:

    ```yaml
    ---
    public:
      hosts:
        my_bridge:
    ```

1. run

    ```bash
    ./site-setup.yaml --limit my_bridge
    ```

1. get its state

    ```bash
    ./site-info.yaml --limit my_bridge
    ```

## Details

The Tor bridges are deployed via an _Ansible_ role with the Debian OS.
The scripts under `./bin` works only for the Hetzner cloud,
_unbound_ is expected as the local DNS resolver.

To setup a private bridge, just replace `public` with `private` in the example above.
