# 02 — Virtualization and the automated VM

Pipeline we chose:

```
Debian netinst ISO ──► Packer (virtualbox-iso builder)
                         │  boots the ISO in a temporary VirtualBox VM
                         │  types a boot command → installer fetches preseed.cfg
                         │  unattended install, then shell provisioners
                         ▼
                    inception-debian.box  (a Vagrant box file)
                         │  vagrant box add
                         ▼
                    Vagrant (Vagrantfile) ──► VirtualBox VM "inception"
                                               └─ Docker + your repo + make
```

---

## Virtual machine and hypervisor

**What is it?** A virtual machine is a complete computer emulated in software:
virtual CPU, RAM, disk, NIC, firmware. It runs its **own kernel** and OS. The
software that creates and runs VMs is a **hypervisor**.
- *Type 1* (bare metal): runs directly on hardware (KVM, Xen, ESXi, Hyper-V).
- *Type 2* (hosted): an application on a host OS (VirtualBox, VMware Workstation).
  VirtualBox still uses CPU hardware extensions (Intel VT-x / AMD-V) through a
  kernel module (`vboxdrv`).

**Why here?** The subject requires that the whole project runs inside a VM. This
gives you a clean, reproducible Linux host where you are root, can install
Docker, edit `/etc/hosts`, and create `/home/alcacere/data`. On 42 machines you
usually don't have root on the host.

**Pitfall on your machine:** `VBoxManage --version` warned that the `vboxdrv`
kernel module isn't loaded for kernel 7.0.0-38. VMs won't start until you run
`sudo /sbin/vboxconfig` (it needs the kernel headers, and your VirtualBox
version must support that kernel).

**Docs**
- VirtualBox manual: <https://www.virtualbox.org/manual/>
- VBoxManage reference: <https://www.virtualbox.org/manual/topics/vboxmanage.html>
- KVM overview: <https://linux-kvm.org/page/Main_Page>

---

## Debian (the VM's OS)

**What is it?** A community Linux distribution known for stability. Releases have
code names: 12 *bookworm*, 13 *trixie* (current stable since Aug 2025).

**Why here?** The subject only constrains the **container** base images
(penultimate Alpine/Debian). The VM OS is free to choose. Debian stable is
well documented, supported by Docker's official apt repository, and supports
**preseeding** (fully automated installs). Use the **current** stable (13) for
the VM.

**Docs**
- Releases: <https://www.debian.org/releases/>
- Installation guide: <https://www.debian.org/releases/stable/amd64/>

---

## Preseed (Debian unattended installation)

**What is it?** A text file of `debconf` answers (`d-i` lines) that the Debian
installer (`debian-installer`, "d-i") reads so it never asks a question:
locale, keyboard, network, mirror, users, partitioning, packages, GRUB.

**Why here?** "Everything must be automated, even the VM installation". Preseed
is the official Debian way to install with no human interaction.

**How it works.** At the ISO's boot menu you pass kernel parameters, e.g.
`auto=true priority=critical url=http://<host>:<port>/preseed.cfg`. Packer starts
a tiny HTTP server serving `vm/packer/http/` and types those parameters for you
(`boot_command`). The installer downloads the file and answers itself.

**Key sections you will write** (`vm/packer/http/preseed.cfg`):
- `d-i debian-installer/locale`, `keyboard-configuration/xkb-keymap`
- `d-i netcfg/get_hostname`, `netcfg/get_domain`
- `d-i mirror/http/hostname`, `mirror/http/directory`
- `d-i passwd/root-login boolean false` (no root login, use sudo)
- `d-i passwd/user-fullname`, `passwd/username`, `passwd/user-password-crypted`
  (a hash is still a credential, so never commit it. Our `preseed.cfg` is a template:
  `build-box.sh` generates a random password + hash, and Packer inserts the hash at build time)
- `d-i partman-auto/method string lvm` (+ the confirm lines)
- `tasksel tasksel/first multiselect standard, ssh-server`
- `d-i pkgsel/include string sudo curl ca-certificates ...`
- `d-i grub-installer/bootdev string default`
- `d-i preseed/late_command string ...` (last-minute commands into `/target`)
- `d-i finish-install/reboot_in_progress note`

**Pitfalls**
- A single wrong key makes the installer stop and **ask a question**, and the build
  waits until `ssh_timeout`. Watch the VirtualBox window (`headless = false`) while debugging.
- Partitioning needs all the `partman/confirm*` lines or it will ask.

**Docs**
- Appendix B, "Automating the installation using preseeding":
  <https://www.debian.org/releases/stable/amd64/apb.en.html>
- Official example file: <https://www.debian.org/releases/stable/example-preseed.txt>

---

## Packer

**What is it?** A HashiCorp tool that builds **machine images** from a template
(written in **HCL2**). It is "infrastructure as code" for images.

**Why here?** It automates *creating* the VM (VirtualBox settings), *installing*
the OS (boot command + preseed), *provisioning* it (shell scripts install Docker…)
and *packaging* the result as a Vagrant box. Prebuilt boxes like `bento/debian-12`
(used by the reference) skip the installation. With Packer you do the installation yourself.

**How it works (HCL blocks)**
- `packer { required_plugins { virtualbox = {...} vagrant = {...} } }`: plugins
  are downloaded with `packer init`.
- `variable "..." {}`: inputs (ISO URL, checksum, CPUs, RAM, login).
- `source "virtualbox-iso" "debian" {...}`: **how to build**: `iso_url`,
  `iso_checksum`, `guest_os_type = "Debian_64"`, `cpus`, `memory`, `disk_size`,
  `http_content` (serves the rendered preseed from memory), `boot_wait`, `boot_command`, `ssh_username`, `ssh_password`,
  `ssh_timeout`, `shutdown_command`, `headless`.
- `build { sources = [...]  provisioner "shell" {...}  post-processor "vagrant" {...} }`:
  **what to do** after the OS is installed and how to package it.

**Key commands**
```
packer init vm/packer            # download plugins
packer fmt vm/packer             # format HCL
packer validate vm/packer        # check the template
packer build vm/packer           # build → output .box
```

**Install without sudo** (useful on 42 machines): download the single binary
from <https://developer.hashicorp.com/packer/install>, put it in `~/bin`, add to `PATH`.

**Docs**
- Packer docs: <https://developer.hashicorp.com/packer/docs>
- HCL templates: <https://developer.hashicorp.com/packer/docs/templates/hcl_templates>
- VirtualBox ISO builder: <https://developer.hashicorp.com/packer/integrations/hashicorp/virtualbox/latest/components/builder/iso>
- Vagrant post-processor: <https://developer.hashicorp.com/packer/integrations/hashicorp/vagrant/latest/components/post-processor/vagrant>
- Shell provisioner: <https://developer.hashicorp.com/packer/docs/provisioners/shell>
- Boot command syntax: see the "Boot Configuration" section of the VirtualBox ISO builder page above

---

## Vagrant

**What is it?** A HashiCorp tool that manages the **lifecycle** of development
VMs from a `Vagrantfile` (Ruby DSL): create, boot, provision, ssh, halt, destroy.
It drives a *provider* (VirtualBox here).

**Why here?** Packer makes the image. Vagrant turns it into a running, configured
VM with one command (`vagrant up`), sets up port forwarding/networks, syncs the
project folder and gives you `vagrant ssh`.

**Vagrant box contract** (what Packer's image must respect so Vagrant can use it):
- A user `vagrant` with passwordless `sudo`. Vagrant's docs suggest the password `vagrant`, but it's
  only a convention. We use a random password during the build, then remove it: Vagrant logs in by key.
- The Vagrant **insecure public key** in `~vagrant/.ssh/authorized_keys`
  (Vagrant replaces it with a fresh private key on the first `vagrant up`).
- SSH server enabled.
- See <https://developer.hashicorp.com/vagrant/docs/boxes/base>.

**SSH in our box:** `PasswordAuthentication no`, applied from the box's first boot, because Packer
needs the password until the build ends. Only `vagrant` has a key, so log in with `vagrant ssh`, then
`sudo -iu alcacere`. Nobody can log in on the VirtualBox console, because no account has a password.

**Key Vagrantfile settings you'll write**
- `config.vm.box = "inception-debian"` (the box Packer produced)
- `config.vm.hostname`
- `config.vm.provider "virtualbox" do |vb| vb.memory / vb.cpus / vb.gui end`
- `config.vm.network "private_network", ip: "192.168.56.42"` or `forwarded_port`
- `config.vm.synced_folder "..", "/home/alcacere/inception", type: "rsync"`
- `config.vm.provision "shell", path: ...` (only what is not baked into the box)

**How to reach `https://alcacere.42.fr` from a browser** (an option for you to choose):
1. **Host-only / private network** (`192.168.56.42`) + host `/etc/hosts` line
   `192.168.56.42 alcacere.42.fr` → needs sudo on host.
2. **GUI inside the VM** (preseed installs a light desktop + Firefox). Works on
   42 machines without sudo, and the VM's own `/etc/hosts` resolves the domain.
   The eval says "open https://login.42.fr in your browser", so this option is the most robust.
3. **SSH SOCKS proxy** (`vagrant ssh -- -D 9999 -N`) + Firefox "Proxy DNS when
   using SOCKS v5" (what the reference does).

**Key commands**
```
vagrant box add --name inception-debian output/inception-debian.box
vagrant up | vagrant ssh | vagrant halt | vagrant reload | vagrant destroy -f
vagrant rsync           # push the project again
vagrant status | vagrant box list
```

**Docs**
- Vagrant docs: <https://developer.hashicorp.com/vagrant/docs>
- Vagrantfile: <https://developer.hashicorp.com/vagrant/docs/vagrantfile>
- VirtualBox provider: <https://developer.hashicorp.com/vagrant/docs/providers/virtualbox/configuration>
- Networking: <https://developer.hashicorp.com/vagrant/docs/networking>
- Rsync synced folders: <https://developer.hashicorp.com/vagrant/docs/synced-folders/rsync>
- Shell provisioner: <https://developer.hashicorp.com/vagrant/docs/provisioning/shell>

---

## Installing Docker inside the VM

**What?** Docker Engine (daemon `dockerd`, `containerd`, `runc`) + CLI + the
**Compose v2 plugin** (`docker compose`, with a space). The old Python
`docker-compose` (with a hyphen) is deprecated.

**Why from Docker's apt repo?** Debian's `docker.io` package is older and may not
include the compose plugin. The official procedure adds Docker's GPG key and repo.

**Steps your provisioning script performs** (`vm/packer/scripts/provision.sh`):
1. Remove conflicting packages (`docker.io`, `docker-compose`, `podman-docker`…).
2. Install `ca-certificates curl`, add the key to `/etc/apt/keyrings/docker.asc`.
3. Add the repo in `/etc/apt/sources.list.d/docker.list` (signed-by the key).
4. `apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`.
5. `usermod -aG docker alcacere` (post-install: run docker without sudo. Note that
   membership in the `docker` group is **equivalent to root**, and you should be able to explain that).
6. Add `127.0.0.1 alcacere.42.fr` to `/etc/hosts`.
7. Create `/home/alcacere/data` (or let the Makefile do it; the Makefile is better because `fclean` removes it).

**Docs**
- Install on Debian: <https://docs.docker.com/engine/install/debian/>
- Post-install: <https://docs.docker.com/engine/install/linux-postinstall/>
- Docker daemon attack surface (docker group = root): <https://docs.docker.com/engine/security/#docker-daemon-attack-surface>

---

## `/etc/hosts` and the domain name

**What?** A static table mapping hostnames to IPs, consulted before DNS (order set
in `/etc/nsswitch.conf`).

**Why?** The subject wants `alcacere.42.fr` to point to your local IP. Without a
real DNS record, a hosts entry is the standard way to do it.

**Docs:** `man 5 hosts`: <https://man7.org/linux/man-pages/man5/hosts.5.html>
