# A stack to deploy Tor bridges
The deployment is made via an _Ansible_ role.
Debian is the supported OS.
The shell scripts works for Hetzner VPS.
They do expect _unbound_ as a local resolver.

### Usage
Create a Tor bridge *my_public_bridge* within the Hetzner cloud project _public_.
1. Create the file `secrets/local.yaml` eg.:

```yaml
---
contact_info: 'see https://github.com/nusenu/ContactInfo-Information-Sharing-Specification'
obfs4_port: 2323
seed_or_port: 'a-random-string'
```
2. Create the VPS

```bash
./bin/create-server.sh public my_public_bridge
```
3. Add it to the ansible inventory subgroup `setup` of the group `public`:

```yaml
---
public:
  children:
    setup:
      hosts:
        my_public_bridge:
    deployed:
      hosts:
    readonly:
      hosts:

private:
  children:
    setup:
      hosts:
    deployed:
      hosts:
```
4. Run

```bash
./site-setup.yaml
```
5. Move the host `my_public_bridge` from `setup` to `deployed`
6. Get the bridge line

```bash
./site-bridgeline.yaml
```

That's all.
