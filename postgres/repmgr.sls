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
        data_dir: {{ postgres.data_dir }}

{%- if postgres.use_sudo %}
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
