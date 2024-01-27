{
  description = "Description for the project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ self, flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # To import a flake module
        # 1. Add foo to inputs
        # 2. Add foo as a parameter to the outputs function
        # 3. Add here: foo.flakeModule

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
        nixosModules.technitium = let
          lib = nixpkgs.lib;
          inherit (lib) types mkEnableOption mkOption;
          inherit (self.packages.${nixpkgs.stdenv.hostPlatform.system}) technitium dotnet-sdk_7;
          config = nixpkgs.config;
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
              dotnetPackage = mkOption {
                type = types.package;
                default = dotnet-sdk_7;
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
                ExecStart = "${cfg.dotnetPackage} \"${cfg.package}/DnsServerApp.dll\" \"${cfg.dataDir}\"";
                StateDirectory = "technitium";
                StateDirectoryMode = "0750";
              };
            };
          };
        };
      };
    };
}
