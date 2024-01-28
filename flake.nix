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
            version = "11.5.3";
            src = pkgs.fetchzip {
              url = "https://download.technitium.com/dns/archive/11.5.3/DnsServerPortable.tar.gz";
              stripRoot = false;
              sha256 = "sha256-he3WXIbnMvACJgLVr2/9rE41r8AUzHDG7B4foRQPmpM=";
            };
            buildInputs = with pkgs; [ dotnet-sdk_7 ];
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
          dotnet = pkgs.dotnetCorePackages.sdk_7_0;
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
            security.wrappers = {
              technitium = {
                owner = "root";
                group = "root";
                capabilities = "cap_net_raw,cap_net_admin,cap_dac_override+eip"; #This needs to be trimmed down to the needed elements.
                source = "${cfg.dotnetPackage}/dotnet"; #Is there a way to do this on DnsServerApp.dll?
              };
            };

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
                StateDirectory = "technitium";
                StateDirectoryMode = "0750";
              };
            };
          };
        };
      };
    };
}
