{ config, ...}:
{

  imports = 
    [
      ../../../../modules/alertmanager-irc-relay.nix
    ];

  services.prometheus = {
    enable = true;

    alertmanager =  {
      enable = true;
      configuration = {
        route = {
          receiver = "all";
          group_by = [ "alertname" ];
          group_wait = "30s";
          group_interval = "30s"; # change back to 2m
         # repeat_interval = "24h";
        };
        receivers = [{
          name = "all";
          webhook_configs = [{ send_resolved = false; url = "http://localhost:16320/hsmr-test"; }];
        }];
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
       # irc_nickname_password = "supersicher"; # TODO
        irc_channels = [ { name = "#hsmr-test"; } ];
        use_privmsg = false;
        msg_template = "{{ .Annotations.summary }}";
      };
    };

    rules = let
    in [
      (builtins.toJSON {
        groups = [
          {
            name = "all";
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

    scrapeConfigs = [
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

}
