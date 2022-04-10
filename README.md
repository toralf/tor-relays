# A stack to deploy Tor relays
Only bridges are supported currently.
The deployment is made via an _Ansible_ role.
Only Debian is supported.
The shell scripts works for Hetzner VPS only.
They do expect _unbound_ as a local resolver.

### Usage
1. Create `secrets/local.yaml` like:

```yaml
---
obfs4_port: 2323
seed_or_port: 'a-random-string'
contact_info: 'see https://github.com/nusenu/ContactInfo-Information-Sharing-Specification'
nickname_prefix: ''
```
2. Create a VPS (name i.e. is `my_public_bridge`)

```bash
./bin/create-server.sh public my_public_bridge
```
3. Add the host to the subgroup `setup` of the group `public`:

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
./site-bridgeline.yaml --limit my_public_bridge
```
7. Run

```bash
./site-info.yaml --limit my_public_bridge
```

That's all.
