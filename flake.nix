{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [

      ];
      systems = [ "x86_64-linux" "aarch64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        packages = rec {
          technitium = pkgs.stdenv.mkDerivation rec {
            name = "technitium";
            version = "12.0.1";
            src = pkgs.fetchzip {
              url = "https://download.technitium.com/dns/archive/12.0.1/DnsServerPortable.tar.gz";
              stripRoot = false;
              sha256 = "sha256-Cvz4O+FBQa9N33q50HDIawqfNFH9Ads4W9pZj15awpQ=";
            };
            buildInputs = with pkgs; [ dotnetCorePackages.sdk_8_0 ];
            installPhase = ''
              mkdir -p $out;
              mv * $out;
            '';
          };
          default = technitium;
        };
      };
      flake = {
        nixosModules.technitium = {config,lib,pkgs, ...}: let
          inherit (lib) types mkEnableOption mkOption;
          technitium = self.packages.${pkgs.system}.technitium;
          dotnet = pkgs.dotnetCorePackages.sdk_8_0;
          cfg = config.services.technitium;
        in {
          options = {
            services.technitium = {
              enable = mkEnableOption ''
                Technitium DNS Server: A simple DNS server for personal use.
              '';

              package = mkOption {
                type = types.package;
                default = technitium;
                description = ''
                  The Technitium package to use with the service.
                '';
              };
              dataDir = mkOption {
                type = types.str;
                default = "/etc/dns";
                description = ''
                  The data storage directory to use with the service.
                '';
              };
              dotnetPackage = mkOption {
                type = types.package;
                default = dotnet;
                description = ''
                  The Dotnet package to use with the service.
                '';
              };
            };
          };
          config = lib.mkIf cfg.enable {
            users.users.technitium = {
              description = "DNS daemon user";
              isSystemUser = true;
              group = "technitium";
            };

            users.groups.technitium = {};

            systemd.services.technitium = {
              description = "Technitium DNS Server";
              documentation = [ "https://technitium.com/dns/" ];
              after = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                User = "technitium";
                Group = "technitium";
                Restart = "always";
                ExecStart = "${cfg.dotnetPackage}/dotnet \"${cfg.package}/DnsServerApp.dll\" \"${cfg.dataDir}\"";
                CapabilityBoundingSet="CAP_NET_BIND_SERVICE";
                AmbientCapabilities="CAP_NET_BIND_SERVICE";
                StateDirectory = "technitium";
                StateDirectoryMode = "0750";
              };
            };
          };
        };
      };
    };
}
