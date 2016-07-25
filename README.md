
emqttd_auth_http
================

Authenticate by HTTP API

Build
-----

This project is a plugin for emqttd broker. In emqttd project:

If the submodule exists:

```
git submodule update --remote plugins/emqttd_auth_http
```

Orelse:

```
git submodule add https://github.com/emqtt/emqttd_auth_http.git plugins/emqttd_auth_http

make && make dist
```

Configuration
-------------

File: etc/plugin.config

```erlang
[

  {emqttd_auth_http, [

    %% Variables: %u = username, %c = clientid, %a = ipaddress, %t = topic

    {super_req, [
      {method, post},
      {url, "http://localhost:8080/mqtt/superuser"},
      {params, [
        {username, "%u"},
        {clientid, "%c"}
      ]}
    ]},

    {auth_req, [
      {method, post},
      {url, "http://localhost:8080/mqtt/auth"},
      {params, [
        {clientid, "%c"},
        {username, "%u"},
        {password, "%P"}
      ]}
    ]},

    %% 'access' parameter: sub = 1, pub = 2

    {acl_req, [
      {method, post},
      {url, "http://localhost:8080/mqtt/acl"},
      {params, [
        {access,   "%A"},
        {username, "%u"},
        {clientid, "%c"},
        {ipaddr,   "%a"},
        {topic,    "%t"}
      ]}
    ]}

    %%auto sub when client connected

    {sub_req, [
      {method, post},
      {url, "http://172.16.7.242:7090/mqtt/sub"},
      {params, [
        {username, "%u"},
        {clientid, "%c"}
      ]}
    ]},

    %% off line, the host is the ip of the emqttd server, if needed config it

    {offline_req, [
      {method, post},
      {url, "http://172.16.7.242:7090/mqtt/offline?host=172.16.7.14"},
      {params, [
        {clientid, "%c"}
      ]}
    ]},

    %% after auto sub to do something, example: after sub send the offline message, etc.
    {after_sub_req, [
      {method, post},
      {url, "http://172.16.7.242:7090/mqtt/aftersub"},
      {params, [
        {clientid, "%c"},
        {topics, "%o"}
      ]}
    ]}
  ]}

].
```

Load the Plugin
---------------

```
./bin/emqttd_ctl plugins load emqttd_auth_http
```

HTTP API
--------

200 if ok

4xx if unauthorized

License
-------

Apache License Version 2.0

Author
------

feng at emqtt.io

