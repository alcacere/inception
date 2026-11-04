# 06 — NGINX and TLS

## NGINX

**What is it?** A high-performance, event-driven **web server** and **reverse
proxy**. A master process reads the config and manages **worker** processes, and each
worker handles thousands of connections with non-blocking I/O.

**Why here?** The subject requires an NGINX container that is the **only entry
point**, on **443**, with **TLS 1.2/1.3 only**. NGINX terminates TLS, serves static
files (CSS/JS/images of WordPress) and forwards `.php` requests to PHP-FPM via
**FastCGI**. It can also reverse-proxy bonus web UIs (Adminer, static site,
Prometheus) so that everything goes through one TLS port.

**How a request flows**
```
Browser ─HTTPS:443─► nginx (TLS termination)
                       ├─ /wp-content/*.css → served from the shared wordpress volume
                       └─ *.php → fastcgi_pass wordpress:9000 → php-fpm runs index.php
                                                                   └─ SQL → mariadb:3306
```
NGINX needs to **see the WordPress files** (same volume, to serve static files and for
`try_files`), but it **never executes PHP**.

**Config structure**
```nginx
# main context
worker_processes auto;
daemon off;                     # foreground → PID 1 (or pass -g 'daemon off;')
events { worker_connections 1024; }
http {
    include mime.types;
    server {                    # a virtual host
        listen 443 ssl;
        server_name alcacere.42.fr;
        ssl_certificate     /etc/nginx/ssl/inception.crt;
        ssl_certificate_key /etc/nginx/ssl/inception.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        root /var/www/html;
        index index.php;
        location / { try_files $uri $uri/ /index.php?$args; }
        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_pass wordpress:9000;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        }
    }
}
```

**Key directives**
- `listen 443 ssl;` enables TLS on the socket. No `listen 80` anywhere → port 80 refuses connections.
- `server_name` matches the `Host` header.
- `location` matching: exact `=`, prefix `^~`, regex `~` / `~*` (case-insensitive), plain prefix.
- `try_files`: tries the files in order and falls back to `index.php` (WordPress "pretty permalinks").
- `fastcgi_pass host:port` sends the request using the FastCGI protocol.
- `fastcgi_param SCRIPT_FILENAME` tells PHP-FPM **which file** to execute. The path
  must exist *inside the WordPress container*, so mount the volume at the same path in both.
- `include fastcgi_params;` adds the standard CGI variables (QUERY_STRING, REQUEST_METHOD…).
- `proxy_pass http://website:8080;` is HTTP reverse proxying (for bonus UIs).
- `server_tokens off;` hides the version.

**Commands**
```
nginx -t                   # test config syntax (run it inside the container)
nginx -T                   # dump the full resolved config
nginx -s reload            # reload without downtime
```

**Pitfalls**
- Forgetting `daemon off;` makes the container exit immediately.
- Wrong `SCRIPT_FILENAME` or different mount paths make PHP-FPM answer "File not found." / 404.
- `ports: "80:80"`: ☠ the eval requires that port 80 does not answer.
- `$uri`, `$args` inside a template rendered with `envsubst` get **erased** unless you
  restrict envsubst to your variables: `envsubst '${DOMAIN_NAME}' < tpl > conf`.

**Docs**
- Docs index: <https://nginx.org/en/docs/>
- Beginner's guide: <https://nginx.org/en/docs/beginners_guide.html>
- Core module (`daemon`, `worker_processes`): <https://nginx.org/en/docs/ngx_core_module.html>
- HTTP core (`server`, `location`, `try_files`): <https://nginx.org/en/docs/http/ngx_http_core_module.html>
- How server names work: <https://nginx.org/en/docs/http/server_names.html>
- FastCGI module: <https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html>
- Proxy module: <https://nginx.org/en/docs/http/ngx_http_proxy_module.html>
- WordPress on NGINX: <https://developer.wordpress.org/advanced-administration/server/web-server/nginx/>

---

## TLS / SSL

**What is it?** **TLS** (Transport Layer Security) is the protocol that encrypts
HTTP into HTTPS and authenticates the server. "SSL" is its deprecated predecessor
(SSLv2/v3 are broken, TLS 1.0/1.1 are deprecated by RFC 8996).

**Why only 1.2/1.3?** The older versions have known attacks (POODLE, BEAST) and weak ciphers.
TLS 1.3 (RFC 8446) has a faster handshake (1-RTT), forward secrecy by default, and removes
legacy algorithms.

**How the handshake works (simplified)**
1. Client Hello: supported versions + cipher suites + key share.
2. Server Hello: chosen version/cipher + **certificate** + key share.
3. Client verifies the certificate chain (signature, name, dates). With a
   self-signed certificate this check fails, which is why the browser shows a warning (accepted by the subject).
4. Both derive the same session keys (ECDHE), and the rest is symmetric encryption (AES-GCM / ChaCha20).

**Certificate + private key**
- The **private key** stays secret on the server (`.key`). It's used to prove identity.
- The **certificate** (`.crt`, X.509) contains the public key, the subject (CN), the
  **SAN** (Subject Alternative Name: browsers check *this*, not CN), validity dates,
  and the issuer's signature. Self-signed means issuer = subject.

**Generate a self-signed cert (one command)**
```
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /etc/nginx/ssl/inception.key -out /etc/nginx/ssl/inception.crt \
  -subj "/C=ES/ST=Madrid/L=Madrid/O=42/OU=student/CN=alcacere.42.fr" \
  -addext "subjectAltName=DNS:alcacere.42.fr"
```
- `-x509` outputs a certificate (not a CSR). `-nodes` means no passphrase on the key
  (otherwise nginx asks for one at start). `-newkey rsa:2048` creates a new key.

**When to generate it?**
- At **build** time (`RUN openssl ...`): simple, but the key is baked into the image layer.
- At **runtime** in the entrypoint, *only if missing*: the key never lives in the image.
  This is the better choice; explain it as a design decision.

**Demonstrate TLS to the evaluator** (eval: "must be demonstrated")
```
openssl s_client -connect alcacere.42.fr:443 -tls1_2 </dev/null   # works
openssl s_client -connect alcacere.42.fr:443 -tls1_3 </dev/null   # works
openssl s_client -connect alcacere.42.fr:443 -tls1_1 </dev/null   # fails (handshake failure)
curl -vk https://alcacere.42.fr 2>&1 | grep -E "SSL connection|TLSv"
curl -v http://alcacere.42.fr          # connection refused (no port 80)
```
And in the browser: padlock → certificate details.

**Docs**
- NGINX SSL module: <https://nginx.org/en/docs/http/ngx_http_ssl_module.html>
- Configuring HTTPS servers: <https://nginx.org/en/docs/http/configuring_https_servers.html>
- Mozilla SSL config generator: <https://ssl-config.mozilla.org/>
- `openssl req`: <https://docs.openssl.org/3.0/man1/openssl-req/>
- `openssl s_client`: <https://docs.openssl.org/3.0/man1/openssl-s_client/>
- TLS 1.3 RFC 8446: <https://datatracker.ietf.org/doc/html/rfc8446>
- Deprecating TLS 1.0/1.1, RFC 8996: <https://datatracker.ietf.org/doc/html/rfc8996>
