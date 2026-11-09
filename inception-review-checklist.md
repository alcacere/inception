# Inception Review Checklist

Review of `alcacere_inception` against the subject (`inception_en_subject.pdf`) and the eval sheet (`inception.pdf`), 9 Nov 2026.

The MariaDB findings come from tests on your real image. Everything else comes from reading the code: the VM was off, so the full stack wasn't run.

Tick a box by changing `[ ]` to `[x]`.

---

## 🔴 Critical: will fail the evaluation

Each of these can end the evaluation on its own. Fix these first.

- [x] **Write `README.md`, `USER_DOC.md` and `DEV_DOC.md`**
  - **Where:** `README.md`, `USER_DOC.md`, `DEV_DOC.md`
  - **Problem:** all three still contain only the skeleton comment blocks. The README's first line is `<!--`.
  - **Why it matters:** the subject lists them under "Prerequisites for validation". The README needs the italic first line, the Description, Instructions, Resources and Project description sections, the four comparisons, and a description of how AI was used.
  - **Fix:** write them yourself, following the sections in each comment block. Your commit messages say the website was "vibecoding using ia" and the snake game was copied from GitHub, so say both in the AI and Resources sections.

- [x] **MariaDB lets root log in without a password** *(tested on your image)*
  - **Where:** `srcs/requirements/mariadb/tools/entrypoint.sh:30`
  - **Problem:** `mariadb-install-db` creates `root@<container-hostname>`, `root@127.0.0.1` and `root@::1` with no password. Your bootstrap only sets a password on `root@localhost`. In my test of your image, `mariadb -u root -h <own hostname or IP>` inside the container logged in as root.
  - **Why it matters:** the eval sheet says that if root logs in without a password, "the evaluation process ends now". `root@127.0.0.1` is only blocked because MariaDB maps that address to `localhost`. Adding `skip-name-resolve` would open it too.
  - **Fix:** replace `DELETE FROM mysql.user WHERE User='';` with:
    ```sql
    DELETE FROM mysql.global_priv WHERE User='' OR (User='root' AND Host<>'localhost');
    ```
    Tested on a copy:
    - The bootstrap ran with no errors, and only `root@localhost` was left.
    - Root without a password was denied.
    - Root with its password and `wp_dbuser` both worked.

    Then run `make fclean`, because this only runs on first install.

---

## 🟠 High

A bonus failure that takes the site down, possible data loss, or a broken bonus.

- [x] **NGINX can't start unless every bonus service is healthy**
  - **Where:** `srcs/docker-compose.yml:43-47, 70-78`
  - **Problem:** `nginx` waits for `adminer`, `website` and `prometheus` to be healthy, and `wordpress` waits for `redis`.
  - **Why it matters:** if one bonus container fails its healthcheck, the WordPress site never comes up. The mandatory part must work "without any malfunctions", so a bonus problem costs you the mandatory part and the bonus with it.
  - **Fix:** keep only `wordpress` in nginx's `depends_on`, and drop `redis` from WordPress's. For each bonus location, add a resolver and proxy through a variable. NGINX then starts anyway, and only that path returns 502. A variable stops `proxy_pass` from stripping the prefix, so add a `rewrite`:
    ```nginx
    resolver 127.0.0.11 valid=10s;
    location /portfolio/ {
        set $website http://website:8080;
        rewrite ^/portfolio/(.*)$ /$1 break;
        proxy_pass $website;
    }
    ```

- [x] **`cluster-setup.sh` can delete your virtual machines**
  - **Where:** `vm/scripts/cluster-setup.sh:40, 47, 52`
  - **Problem:** when `/goinfre` exists, it runs `rm -rf ~/.vagrant.d`, `~/.cache/packer` and `~/VirtualBox VMs` without asking. `make vm` and `make vm-box` call it automatically.
  - **Why it matters:** on a school computer, the first `make vm` deletes every VM disk and Vagrant box you have, other projects' included. It also changes VirtualBox's VM folder for every project.
  - **Fix:** only create a link when the folder is missing or empty. If it has content, move it with `mv` or stop with a message. Run it only through `make cluster`, not from `up.sh` and `build-box.sh`.

- [x] **WordPress and FTP fight over file ownership**
  - **Where:** `wordpress/tools/entrypoint.sh:57`, `bonus/ftp/tools/entrypoint.sh:30`
  - **Problem:** WordPress runs `chown -R nobody` (UID 65534) on every start. FTP runs `chown -R 1000:1000` on the same volume, and it starts last, so it wins.
  - **Why it matters:** PHP runs as `nobody`, so it can't write: media uploads and plugin and core updates fail. If WordPress restarts, FTP loses write access instead. The eval sheet says to test that each bonus service works.
  - **Fix:** use one UID for both.
    - Create a `www` user with UID 1000 in the WordPress image, and set `user = www` in `www.conf`.
    - Give the FTP user the same UID, with `-s /sbin/nologin`.
    - Run `chown` only on first install.

---

## 🟡 Medium

Security and correctness problems an evaluator could ask you about.

- [x] **`chmod -R 755` makes `wp-config.php` readable by everyone**
  - **Where:** `wordpress/tools/entrypoint.sh:58`
  - **Problem:** on every start, every file becomes `755`, including `wp-config.php` with the database and Redis passwords in plain text.
  - **Why it matters:** any user on the VM can read `/home/alcacere/data/wordpress/wp-config.php`. Marking every file as executable is wrong too.
  - **Fix:**
    ```sh
    find /var/www/html -type d -exec chmod 755 {} +
    find /var/www/html -type f -exec chmod 644 {} +
    chmod 640 /var/www/html/wp-config.php
    ```

- [ ] **`/prometheus/` and `/adminer` have no login**
  - **Where:** `nginx/conf/inception.conf.template:38-60`, `bonus/adminer/Dockerfile:13`
  - **Problem:**
    - Anyone who can reach port 443 can browse Prometheus, which shows your internal hostnames and ports.
    - Your Adminer 4.8.1 is from 2021, and the current release is 6.3.0.
    - Adminer's login form accepts any server address, so it can be used to probe your internal network.
  - **Why it matters:** these are admin tools exposed on your only public entry point.
  - **Fix:**
    - Put `auth_basic` with an `.htpasswd` built from a Docker secret in front of both paths.
    - Update Adminer's version and SHA-256.
    - Optionally, limit Adminer's server field to `mariadb`.

- [x] **A fresh clone gets new passwords that don't match the old data**
  - **Where:** `srcs/requirements/tools/generate-secrets.sh`
  - **Problem:** if `secrets/` is regenerated while `/home/alcacere/data` still holds the old database and WordPress install, the files no longer match the accounts. The site keeps working, because `wp-config.php` keeps the old password.
  - **Why it matters:** an evaluator who follows your docs and logs in with `secrets/wp_admin_password.txt` is refused.
  - **Fix:** in `generate-secrets.sh`, refuse to create a secret when the data folders already exist, and point to `make fclean` instead.

- [x] **Your local root CA can vouch for any website**
  - **Where:** `nginx/tools/entrypoint.sh:11-14`, `Makefile:28-31`, `provision.sh:191-208`
  - **Problem:** the CA has no name constraints. The VM's system trust store and Firefox both trust it, and `rootCA.key` sits in `/home/alcacere/data/certs`.
  - **Why it matters:** anyone who reads that key can impersonate any site to that browser. The eval sheet says the certificate "doesn't have to be recognized", so this is an extra. Your two-tier reasoning is correct.
  - **Fix:** limit the CA to your domain, which also makes a strong point at the defense:
    ```sh
    -addext "nameConstraints=critical,permitted;DNS:alcacere.42.fr"
    ```

- [ ] **FTP sends your password and files unencrypted**
  - **Where:** `bonus/ftp/conf/vsftpd.conf`
  - **Problem:** `ssl_enable` isn't set, so logins and file contents cross the network in plain text.
  - **Why it matters:** the subject doesn't require FTPS, but an evaluator focused on security will ask.
  - **Fix:** turn on FTPS with a certificate signed by your CA. At minimum, explain this at the defense.
    ```
    ssl_enable=YES
    force_local_logins_ssl=YES
    force_local_data_ssl=YES
    ```

- [x] **The copied snake game has no credit**
  - **Where:** `bonus/website/site/index.html`
  - **Problem:** your commit message says the snake game was copied from a public GitHub repo, but the code doesn't credit it.
  - **Why it matters:** it's a licence problem, and the subject's AI rules say you must fully understand what you submit.
  - **Fix:** credit the repo URL and its licence in the README Resources section, or rewrite the game yourself.

---

## 🟢 Low

Small fixes and cleanup. Quick to do, and they make the defense smoother.

- [x] **Remove the stray `[wordpress` file**: an empty file named `[wordpress` was committed in `96c389d`. It's deleted locally but still in the repo. Run `git rm '[wordpress'`.
- [x] **Replace `chmod 777` on Prometheus data** (`Makefile:13`): `sudo chmod -R 777` gives everyone write access. Use `sudo chown -R 100:101 $(DATA_DIR)/prometheus`, since 100:101 is the `prometheus` user in Alpine 3.23.
- [x] **Complete `.PHONY`** (`Makefile:92`): add `vm-rsync`, `vm-auto-rsync`, `vm-suspend` and `vm-resume`.
- [ ] **Define the data path once** (`Makefile:1-2`, `srcs/.env`): `DATA_DIR` and `DATA_PATH` set the same path twice. Read it from `srcs/.env`.
- [ ] **Use or remove unused variables** (`srcs/.env.example`, `check-env.sh`): `CERT_*` is checked but the cert subject is hardcoded. `MYSQL_HOST`, `PROMETHEUS_RETENTION` (hardcoded `7d`) and `REDIS_PORT` in WordPress aren't used. Use them or delete them.
- [ ] **MariaDB healthcheck logs "Access denied" every 5 s** (`docker-compose.yml:20`): `mariadb-admin ping` without credentials still succeeds, but MariaDB logs a warning each time. Accept it and be ready to explain it, or use a dedicated healthcheck user.
- [ ] **Make the WordPress healthcheck lighter** (`docker-compose.yml:49`): it runs a full WP-CLI load as root every 5 s and never checks PHP-FPM. Use `cgi-fcgi -bind -connect 127.0.0.1:9000`, as you did for Adminer.
- [ ] **Hide the Redis password and require the secret** (`docker-compose.yml:98`, `bonus/redis/tools/entrypoint.sh:5-9`): `-a password` is visible in `ps`, and with no secret the entrypoint starts with an empty password. Use the `REDISCLI_AUTH` variable, and exit when the secret is missing, as your FTP entrypoint does.
- [ ] **Pin WP-CLI with a checksum** (`wordpress/Dockerfile:31`): it's downloaded unpinned, with no checksum. Pin a version and its SHA-256, as you did for Adminer.
- [ ] **Tighten `/run/mysqld` and drop `apk update`** (`mariadb/Dockerfile:9`, all Dockerfiles): `chmod 777 /run/mysqld` is wider than needed, so use `755`. `apk update &&` before `--no-cache` leaves a package index in the image, so remove it.
- [ ] **Probe that port 80 is closed and old TLS is refused** (`bonus/blackbox/conf/blackbox.yml`, `prometheus/conf/*`): the `tls_old` module is never used, and nothing probes `nginx:80`. Add those probes plus `Port80Open` and `OldTlsAccepted` alerts. They prove the subject's rules live, which makes a good justification for your free choice.
- [ ] **Note the GUI autologin trade-off** (`vm/packer/scripts/provision.sh:159-168`, `docs/02`): autologin plus passwordless `sudo` means anyone at the VirtualBox window is root. That's fine for a local VM, but mention it at the defense. My sentence in `docs/02` saying nobody can log in on the console is now wrong, so fix it.
- [x] **Delete leftover skeleton comments** (FTP `Dockerfile`, `blackbox.yml`, `check-env.sh`, 9 × `.dockerignore`): AI-written "WRITE:" instructions sit next to your code, and every `.dockerignore` is only comments. Delete the comments, and give each `.dockerignore` real patterns.
- [ ] **Decide what to do with `docs/`**: it's AI-written, partly out of date (it still describes a single self-signed certificate), and contains the forbidden words as warnings. Remove it from the repo you submit, or label it as AI study notes in the README.

---

## ✅ Before the defense

- [ ] **Rebuild from scratch and run the eval sheet**: the MariaDB and ownership fixes only apply to a fresh install. Run `make fclean && make`, then go through the eval sheet:
  - its cleanup command
  - the root login without a password
  - a comment as the regular user
  - a page edit as admin
  - a VM reboot
  - each bonus service

---

## Your changes from the plan

| Change | Verdict |
|---|---|
| Two-tier CA trusted in Firefox | ✅ Correct reasoning. Add name constraints |
| GUI, Firefox and desktop shortcut in the VM | ✅ Lets the evaluator open the site inside the VM. Note the autologin trade-off |
| `cluster-setup.sh` | ⚠️ Good idea, dangerous implementation |
| `vm-rsync`, `vm-auto-rsync` and other VM targets | ✅ Fine. Add them to `.PHONY` |
| `darkhttpd` for the website | ✅ Good fix, well explained in the commit |
| Adminer pinned with SHA-256 | ✅ Best practice, but the version is old |
| Healthchecks + `depends_on` | ✅ Right for mandatory services, wrong for bonus ones |
| `alpine:3.23`, `pull_policy: build`, image = service name, named volumes under `/home/alcacere/data`, `networks`, no `links` or host network, no forbidden commands | ✅ All compliant. 3.23 is still the penultimate release |
| `init: true` on FTP; non-root Blackbox, Prometheus and website | ✅ Good practice |
