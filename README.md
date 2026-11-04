<!--
README.md (required by subject chapter VI)                    READ: docs/01, 05

RULES
  - Written in ENGLISH.
  - The VERY FIRST LINE must be italic and exactly:
      *This project has been created as part of the 42 curriculum by alcacere.*
    (delete this comment block so that line is really the first one)

REQUIRED SECTIONS (write them yourself, in your own words)
  # Description
      Goal of the project and a brief overview (VM → Docker → services diagram).
  # Instructions
      Prerequisites (host: VirtualBox, Packer, Vagrant), how to create the VM
      (make vm), how to create .env + secrets (make secrets), make / make down /
      make fclean, how to reach https://alcacere.42.fr.
  # Resources
      Classic references (pick the best links from docs/*.md) AND a paragraph on
      HOW AI WAS USED: for which tasks (e.g. study guide, skeleton comments,
      reviewing configs) and which parts of the project. Be honest and precise.
  # Project description   (the subject requires this explicitly)
      - Use of Docker in this project and the sources included (srcs/requirements/*)
      - Main design choices (Alpine 3.23, Packer+preseed+Vagrant, secrets,
        healthchecks + depends_on, single TLS entry point, non-root users,
        bind-backed named volumes, bonus via NGINX reverse proxy...)
      - Comparisons (see docs/05):
          ## Virtual Machines vs Docker
          ## Secrets vs Environment Variables
          ## Docker Network vs Host Network
          ## Docker Volumes vs Bind Mounts

OPTIONAL BUT GOOD
  Architecture diagram, list of services and ports, bonus justification
  (Prometheus + Blackbox Exporter).
-->
