[![StandWithUkraine](https://raw.githubusercontent.com/vshymanskyy/StandWithUkraine/main/badges/StandWithUkraine.svg)](https://github.com/vshymanskyy/StandWithUkraine/blob/main/docs/README.md)

# A stack to deploy Tor bridges
The deployment is made via _Ansible_.
Debian _bullseye_ is used as the OS.
The shell scripts under `./bin` works for Hetzner VPS.
As a local DNS resolver _unbound_ is used.

### Usage
To setup a new Tor bridge (i.e. *my_public_bridge*) within the Hetzner cloud project (i.e. _public_) do:
1. Create the file `secrets/local.yaml` eg.:

```yaml
---
contact_info: 'look at https://github.com/nusenu/ContactInfo-Information-Sharing-Specification'
nickname_prefix: 'nickneck'
obfs4_port: 4711
seed_or_port: 'a-no-longer-changed-and-really-random-string-here-please'
```
2. Create the VPS

```bash
./bin/create-server.sh public my_public_bridge
```
3. Add the hostname to `public_bridges`:

```yaml
---
public_bridges:
  children:
    bridges:
      hosts:
        my_public_bridge:
```
4. Run

```bash
./site-public-setup.yaml --limit my_public_bridge
```

That's all.
