alerta
======

`alerta` deploys monitoring for domains, services and servers of Hackspace Marburg using [Prometheus](https://prometheus.io/) with [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) and [Alertmanager IRC Relay](https://github.com/google/alertmanager-irc-relay) using [NixOS](https://nixos.org/).

## Secret management

For not leaking credentials, two relevant NixOS settings are omitted in the repository and are documented here.

```Nix
{

  services.prometheus.alertmanagerIrcRelay.settings.irc_nickname_password = "super-secret-phrase";
  
  services.nginx.virtualHosts."alerta.nau.icu".locations."/".basicAuth = {
    obvious-nickname = "not-so-secret-phrase";
  };

}
```

## TODO

- Change domain for the Alertmanger Web UI to `alerta.hsmr.cc`.

## Etymology

![alt text](hackback.svg)

[Not even kidding, click for source.](https://archive.org/details/hackback)

