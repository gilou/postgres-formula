{% from tpldir + "/map.jinja" import postgres with context %}

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
postgresql-repmgr-sshauth-{{ host }}:
  ssh_auth.present:
        - user: {{ postgres.user }}
        - name: {{ pubkey }}
{%- endfor %}

{%- set mine_hostkeys = salt['mine.get']('n*', 'ssh.host_keys') %}
{%- for host, keys in mine_hostkeys.items() %}
  {%- for name, fullkey in keys.items() %}
  {%- set enc = fullkey.split()[0] %}
  {%- set key = fullkey.split()[1] %}
postgresql-repmgr-sshknown-{{ host }}-{{ name }}:
  ssh_known_hosts.present:
        - user: {{ postgres.user }}
        - name: {{ host }}
        - hash_known_hosts: False
        - enc: {{ enc }}
        - key: {{ key }}
  {%- endfor %}
{%- endfor %}


