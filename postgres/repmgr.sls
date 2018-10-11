{% from tpldir + "/map.jinja" import postgres with context %}

include:
  - postgres.upstream

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
        repmgr: {{ postgres.repmgr }}
        service: {{ postgres.service }}   
        data_dir: {{ postgres.data_dir }}

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
postgresql-repmgr-sshauthkeys:
  ssh_auth.present:
        - user: {{ postgres.user }}
        - name: {{ pubkey }}
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
