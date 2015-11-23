let
    rotorepo = (import <nixpkgs> {}).fetchgit {
      url = /home/sjanssen/rotothopter;
      rev = "8c96206841cceeb717eb1f17a490155a09152ac1";
      sha256 = "05vin88rkyv03kyvhks2cws0802x3adc6vi1zgjylwp9z355pr7n";
      branchName = "sqlify";
    };
    rotostatic = (import "${rotorepo}/release.nix" {  }).rotothopter_static;
    secrets = (import ./prod-secrets.nix);
in
{
    network.description = "Rotothopter Single AWS";

    webserver =
        { config, pkgs, ... }:
        {
            # postgres stuff
            services.postgresql.enable = true;
            services.postgresql.enableTCPIP = false;
            services.postgresql.initialScript = ./sqlsettings.sql;

            # nginx stuff
            services.nginx.enable = true;
            services.nginx.httpConfig =
            ''
            upstream backends {
                server 127.0.0.1:3000;
            }

            server {
                listen 80;
                location ~ ^/draft/[0-9]+/watch {
                    proxy_pass http://backends;
                    proxy_read_timeout 450;
                    chunked_transfer_encoding off;
                    proxy_buffering off;
                }
                location /static/ {
                    alias ${rotostatic}/share/x86_64-linux-ghc-7.10.2/rotothopter-0.0.1/static/;
                }

                location / {
                    proxy_pass http://backends;
                }
            }
            '';
            networking.firewall.allowedTCPPorts = [ 80 ];
            environment.systemPackages = [rotostatic];

            # app stuff
            systemd.services.rotothopter = {
                path = [ rotostatic ];
                after = [ "network.target" "local-fs.target" ];
                requires = [ "postgresql.service" ];
                wantedBy = [ "multi-user.target" "nginx.service" ];
                serviceConfig = {
                    Type = "simple";
                    User = "rotothopter";
                    ExecStart = ''${rotostatic}/bin/rotothopter'';
                    WorkingDirectory = "/var/rotothopter";
                };
                preStart =
                ''
                mkdir -p /var/rotothopter/config
                '';
                environment = {
                    STATIC_DIR = ''${rotostatic}/share/x86_64-linux-ghc-7.10.2/rotothopter-0.0.1/static/'';
                    PORT = "3000";
                    APPROOT = "http://rotothopter.ignorelist.com";
                    PGUSER = "roto";
                    PGPASS = "roto";
                    PGHOST = "127.0.0.1";
                    PGDATABASE = "rotothopter";
                    ALLOW_DUMMY_AUTH = "true";
                    GMAIL_PASSWORD = secrets.gmail_password;
                    GMAIL_ADDRESS = secrets.gmail_address;
                    GOOGLE_CLIENT_ID = secrets.google_client_id;
                    GOOGLE_CLIENT_PASSWORD = secrets.google_client_password;
                };
            };
            users.extraUsers.rotothopter = {
                home = "/var/rotothopter";
                createHome = true;
            };
        };
}