{ config, lib, pkgs, ... }:

let
  mailFrom = "alerts@bunchwebhost.com";
  mailTo = "liam@bunchwebhost.com";
in
{
  sops.secrets.smtp-password.sopsFile = ../secrets/smtp.yaml;

  programs.msmtp = {
    enable = true;
    accounts.default = {
      host = "mail.bunchwebhost.com";
      port = 465;
      tls = true;
      tls_starttls = false;
      tls_trust_file = "/etc/ssl/certs/ca-certificates.crt";
      auth = true;
      user = mailFrom;
      from = mailFrom;
      passwordeval = "${pkgs.coreutils}/bin/cat ${config.sops.secrets.smtp-password.path}";
      timeout = 30;
      syslog = true;
    };
  };

  services.smartd = {
    enable = true;
    extraOptions = [
      "--savestates=/var/lib/smartd/smartd."
      "--attributelog=/var/lib/smartd/attrlog."
    ];
    notifications.mail = {
      enable = true;
      sender = mailFrom;
      recipient = mailTo;
    };
    defaults.autodetected = lib.concatStringsSep " " [
      "-a"
      "-o on"
      "-S on"
      "-n standby,15,q" # don't spin up idle HDDs
      "-s (S/../.././02|L/../../7/03)" # short daily 02:00, long Sunday 03:00
      "-W 0,50,60" # log at 50°C, email at 60°C
    ];
  };

  systemd.services.smartd.serviceConfig.StateDirectory = "smartd";
}
