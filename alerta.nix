{ config, ...}:
{

  services.prometheus = {
    enable = true;

    alertmanager =  {
      enable = true;
      webExternalUrl = "https://alerta.nau.icu";
      configuration = {
        route = 
        let
          defaultRouteCfg = {
            receiver = "all";
            group_by = [ "alertname" ];
          };
          tuerstatusRouteCfg = {
            receiver = "drehtuer";
            group_by = [ "alertname" ];
          };
        in
        defaultRouteCfg // {
          routes = [
            (defaultRouteCfg // {
              matchers = [ "alertname=\"blackbox\"" ];
              repeat_interval = "24h";
            })
            (tuerstatusRouteCfg // {
              matchers = [ "alertname=\"drehtuer\"" ];
            })
          ];
        };
        receivers = [
          {
            name = "all";
            webhook_configs = [{ send_resolved = false; url = "http://localhost:16320/hsmr"; }];
          }
          {
            name = "drehtuer";
            webhook_configs = [{ send_resolved = true; url = "http://localhost:16320/hsmr"; }];
          }
        ];
      };
      logLevel = "warn";
    };

    alertmanagers = [
      {
        static_configs = [
          { targets = [ "localhost:${toString config.services.prometheus.alertmanager.port}" ]; }
        ];
      }
    ];

    alertmanagerIrcRelay = {
      enable = true;
      settings = {
        http_port = 16320;
        http_host = "localhost";
        irc_use_ssl = true;
        irc_host = "irc.hackint.org";
        irc_port = 6697;
        irc_nickname = "alerta";
        irc_channels = [ { name = "#hsmr"; } ];
        use_privmsg = false;
        # TODO omit .Status and .Labels.alertname if it's drehtuer
        msg_template = "[{{ .Status }}] {{ .Labels.alertname }}: {{ .Annotations.summary }}";
      };
    };

    rules = [
      (builtins.toJSON {
        groups = [
          {
            name = "drehtuer";
            rules = [
              {
                alert = "drehtuer_door_open";
                expr = ''(sum_over_time(drehtuer_door_open[3m]) == sum_over_time(drehtuer_door_open[2m])) and (sum_over_time(drehtuer_door_open[2m]) != 0)'';
                annotations = {
                  summary = "Der Space ist geöffnet.";
                };
              }
              {
                alert = "drehtuer_door_closed";
                expr = ''(max_over_time(drehtuer_door_open[3m]) - drehtuer_door_open) == 1'';
                annotations = {
                  summary = "Der Space ist geschlossen.";
                };
              }
#              {
#                alert = "drehtuer_door_flti_open";
#                expr = ''drehtuer_door_flti == 1'';
#                annotations = {
#                  summary = "FTLI*-Zeit hat begonnen.";
#                };
#              }
#              {
#                alert = "drehtuer_door_flti_closed";
#                expr = ''drehtuer_door_flti == 0'';
#                annotations = {
#                  summary = "FLTI*-Zeit hat geendet.";
#                };
#              }
            ];
          }
        ];
      })
    ];
    ruleFiles = [
      ./prometheus/rules-blackbox.yml
      ./prometheus/rules-domain.yml
    ];

    exporters = {
      blackbox = {
        enable = true;
        listenAddress = "127.0.0.1";
        configFile = ./prometheus/exporter-blackbox.yml;
      };

      domain = {
        enable = false; # disable for now because of faulty notices
        listenAddress = "127.0.0.1";
      };
    };

    scrapeConfigs = [
      {
        job_name = "blackbox-http";
        metrics_path = "/probe";
        params = {
          module = [ "http_non_critical" ];
        };
        static_configs = [{
          targets = [
            "https://bbb.hsmr.cc/"
            "https://chat.hsmr.cc/"
            "https://grafana.hsmr.cc/"
            "https://hsmr.cc/"
            "https://ldap.hsmr.cc/"
            "https://zammad.hsmr.cc/"

            "https://firmware.marburg.freifunk.net/"
            "https://marburg.freifunk.net/"
          ];
        }];
        relabel_configs = [
          { source_labels = [ "__address__" ];    target_label = "__param_target"; }
          { source_labels = [ "__param_target" ]; target_label = "instance"; }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}";
          }
        ];
      }
      {
        job_name = "domain";
        metrics_path = "/probe";
        static_configs = [{
          targets = [
            "hsmr.cc"
          ];
        }];
        relabel_configs = [
          { source_labels = [ "__address__" ];    target_label = "__param_target"; }
          { source_labels = [ "__param_target" ]; target_label = "instance"; }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:${toString config.services.prometheus.exporters.domain.port}";
          }
        ];
      }
      {
        job_name = "drehtuer";
        scheme = "http";
        metrics_path = "/metrics";
        static_configs = [{
          targets = [ "b2s.hsmr.cc:9876" ];
        }];
      }
    ];
  };

  services.nginx.virtualHosts."alerta.nau.icu" = {
    forceSSL = true;
    enableACME = true;

    locations."/".proxyPass = "http://localhost:${toString config.services.prometheus.alertmanager.port}";
  };

}
