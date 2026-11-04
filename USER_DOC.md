<!--
USER_DOC.md (required by subject chapter VII)                 READ: docs/01, 12

AUDIENCE: an end user / administrator, NOT a developer. Clear and simple terms.

MUST EXPLAIN HOW TO:
  1. Understand what services the stack provides
     (table: service → what it does → URL/port).
  2. Start and stop the project  (make / make down / make stop / make start).
  3. Access the website and the administration panel
     (https://alcacere.42.fr, https://alcacere.42.fr/wp-admin, self-signed
      certificate warning, how the browser resolves the domain).
  4. Locate and manage credentials
     (usernames in srcs/.env, passwords in secrets/*.txt, make secrets to
      generate them, why changing one after first boot requires make fclean).
  5. Check that the services are running correctly
     (make ps → all "healthy", make logs, quick curl/openssl checks).
-->
