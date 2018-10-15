{% from tpldir + "/map.jinja" import postgres with context %}

include:
  - postgres.upstream
  - postgres.server

postgresql-repmgr:
  pkg.installed:
    - name: {{ postgres.pkg_repmgr}}
  {% if postgres.fromrepo %}
    - fromrepo: {{ postgres.fromrepo }}
  {% endif %}
  {% if postgres.use_upstream_repo == true %}
    - refresh: True
    - require:
      - pkgrepo: postgresql-repo
  {% endif %}

postgresql-repmgr-conf:
  file.managed:
    - name: {{ postgres.repmgr_conf_file }}
    - source: "salt://postgres/templates/repmgr.conf.j2"
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        repmgr_conf_file: {{ postgres.repmgr_conf_file }}
        repmgr: {{ postgres.repmgr }}
        service: {{ postgres.service }}
        data_dir: {{ postgres.data_dir }}
        bin_dir: {{ postgres.bin_dir }}


postgresql-replication-conf:
  file.managed:
    - name: {{ postgres.conf_dir }}/postgresql.replication.conf
    - source: "salt://postgres/templates/postgresql.replication.conf.j2"
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - defaults:
        use_repmgrd: {{ postgres.repmgr.use_repmgrd }}

{% if postgres.repmgr.use_repmgrd %}
repmgrd:
  service.running:
    - name: {{ postgres.repmgrd_service }}
    - enable: True
    - watch:
      - postgresql-repmgr-conf
{% endif %}

postgresql-replication-include:
  file.blockreplace:
    - name: {{ postgres.conf_dir }}/postgresql.conf
    - marker_start: "# Managed by SaltStack: repmgr configuration"
    - marker_end: "# Managed by SaltStack: end of salt managed zone for repmgr"
    - content: |
        include 'postgresql.replication.conf'
    - show_changes: True
    - append_if_not_found: True
    {#- Detect empty values (none, '') in the config_backup #}
    - backup: {{ postgres.config_backup|default(false, true) }}
    - require:
      - file: postgresql-config-dir
    - watch:
      - file: postgresql-replication-conf
    - watch_in:
      - module: postgresql-service-restart


{% set home = salt["user.info"](postgres.user).home %}
postgresql-repmgr-ssh:
  file.directory:
    - name: {{ home }}/.ssh
    - user: {{ postgres.user }}
    - group: {{ postgres.user }}
    - mode: 700

postgresql-repmgr-sshkey:
  cmd.run:
    - name: ssh-keygen -t rsa -b 4096 -q -f {{ home }}/.ssh/id_rsa -N ""
    - runas: {{ postgres.user }}
    - creates:
      - {{ home }}/.ssh/id_rsa
    - require:
      - postgresql-repmgr-ssh

{%- set mine_keys = salt['mine.get']('n*', 'ssh.user_keys') %}
{%- for host, users in mine_keys.items() %}
{%- set pubkey = users[postgres.user]['id_rsa.pub'] %}
postgresql-repmgr-sshauth{{ host }}:
  ssh_auth.present:
        - user: {{ postgres.user }}
        - name: {{ pubkey }}
{%- endfor %}

{%- set mine_hostkeys = salt['mine.get']('n*', 'ssh.host_keys') %}
{%- for host, keys in mine_hostkeys.items() %}
  {%- for name, fullkey in keys.items() %}
  {%- set enc = fullkey.split()[0] %}
  {%- set key = fullkey.split()[1] %}
postgresql-repmgr-sshknown{{ host }}-{{ name }}:
  ssh_known_hosts.present:
        - user: {{ postgres.user }}
        - name: {{ host }}
        - hash_known_hosts: False
        - enc: {{ enc }}
        - key: {{ key }}
  {%- endfor %}
{%- endfor %}

{%- if postgres.repmgr.use_sudo %}
postgres-repmgr-sudo:
  pkg.installed:
    - name: sudo

postgresql-repmgr-sudoers:
  file.managed:
    - name: /etc/sudoers.d/repmgr
    - source: "salt://postgres/templates/repmgr.sudoers.j2"
    - user: root
    - group: root
    - mode: 600
    - template: jinja
    - defaults:
        service: {{ postgres.service }}
        user: {{ postgres.user }}
    - require:
        - postgres-repmgr-sudo
{% endif %}
