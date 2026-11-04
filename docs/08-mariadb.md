# 08 — MariaDB

## What is it?

A relational database server (SQL), a community fork of MySQL that is protocol-compatible
(WordPress treats it as MySQL). The server binary is `mariadbd`, the client is `mariadb`,
and the admin tool is `mariadb-admin`.

## Why here?

WordPress stores everything except files in it. The subject wants it in its
own container, data in a named volume under `/home/alcacere/data`.

## How it works in a container

1. **Data directory** `/var/lib/mysql` → the `mariadb` named volume.
2. **First start** (empty volume): create the system tables with
   `mariadb-install-db --user=mysql --datadir=/var/lib/mysql`.
3. Run the **one-time SQL**: set the root password, create the WordPress DB,
   create the user and grant privileges.
4. **Every start:** `exec mariadbd` in the foreground (PID 1).

### How to run the one-time SQL without a "background + wait loop"?

Option A (cleanest): **bootstrap mode**. `mariadbd --bootstrap` (or
`mariadbd --init-file=/path/init.sql`) executes SQL statements at startup **without
networking and without a separate background process**:
```
mariadbd --user=mysql --bootstrap < /tmp/init.sql      # runs SQL then exits
exec mariadbd --user=mysql                              # real server, PID 1
```
`--init-file` is similar: the server runs the file every time it starts, so only pass it on first run.
Start the SQL file with `FLUSH PRIVILEGES;` because in bootstrap mode the grant tables are not
loaded yet, and `ALTER USER`/`CREATE USER` need them.

Option B (reference project): start `mariadbd &` temporarily, poll with a
**bounded** loop (timeout counter) using `mariadb-admin ping`, run SQL, shut it
down, `wait`, then `exec`. It works, but you must justify the `&` and the loop to
the evaluator (it's not the ENTRYPOINT's final process and it's bounded).
Option A avoids the discussion.

### The SQL you'll write
```sql
-- secure root: password, no remote root, no anonymous users, no test DB
ALTER USER 'root'@'localhost' IDENTIFIED BY '<root_pw>';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
CREATE DATABASE IF NOT EXISTS `wordpress`;
CREATE USER IF NOT EXISTS 'wp_user'@'%' IDENTIFIED BY '<user_pw>';
GRANT ALL PRIVILEGES ON `wordpress`.* TO 'wp_user'@'%';
FLUSH PRIVILEGES;
```
`'user'@'%'`: the host part is **where the client connects from**. `%` means any host,
which is fine because only containers on the internal network can reach 3306.
(The reference uses the subnet `10.42.1.%`: stricter, but tied to the subnet.)

## Configuration file

`/etc/my.cnf.d/mariadb-server.cnf` on Alpine (it may include `/etc/my.cnf.d/*.cnf`):
```ini
[mariadbd]
bind-address = 0.0.0.0        # listen on the container's network interface, not only 127.0.0.1
port = 3306
skip-networking = 0           # ☠ Alpine's default config has skip-networking ON!
datadir = /var/lib/mysql
socket = /run/mysqld/mysqld.sock
```
`/run/mysqld` must exist and be owned by the `mysql` user.

## ☠ The root-without-password trap (eval: ends the evaluation)

By default `mariadb-install-db` creates `root@localhost` with the **unix_socket**
authentication plugin: if you are the OS user `root` inside the container, then
`mariadb -u root` logs in **without any password**. The eval explicitly tries this.
Fix it with one of:
- `mariadb-install-db --auth-root-authentication-method=normal` + set a password, or
- `ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('...')`
  (or `IDENTIFIED BY`), removing unix_socket.
Test: `docker exec -it mariadb mariadb -u root` → must answer **Access denied**.

## Commands for the defense
```
docker exec -it mariadb mariadb -u root                  # must FAIL
docker exec -it mariadb mariadb -u root -p               # asks password → works
docker exec -it mariadb mariadb -u wp_user -p wordpress
  > SHOW DATABASES;  USE wordpress;  SHOW TABLES;
  > SELECT user_login, user_email FROM wp_users;        # 2 users, admin name w/o "admin"
  > SELECT comment_author, comment_content FROM wp_comments;
```

## Docs
- Docs home: <https://mariadb.com/docs/>
- `mariadb-install-db`: <https://mariadb.com/kb/en/mariadb-install-db/>
- `mariadbd` options (`--bootstrap`, `--init-file`): <https://mariadb.com/kb/en/mariadbd-options/>
- Option files: <https://mariadb.com/kb/en/configuring-mariadb-with-option-files/>
- unix_socket plugin: <https://mariadb.com/kb/en/authentication-plugin-unix-socket/>
- `CREATE USER`: <https://mariadb.com/kb/en/create-user/>
- `GRANT`: <https://mariadb.com/kb/en/grant/>
- `mariadb-admin`: <https://mariadb.com/kb/en/mariadb-admin/>
- `mariadb-dump` (backups): <https://mariadb.com/kb/en/mariadb-dump/>
