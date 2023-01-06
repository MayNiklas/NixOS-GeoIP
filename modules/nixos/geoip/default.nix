{ config, lib, pkgs, ... }:
with lib;
let cfg = config.mayniklas.geoip;
in
{

  options.mayniklas.geoip = {
    enable = mkEnableOption "activate geoip";
    AccountID = mkOption {
      type = types.int;
      example = 123456;
      description = "MaxMind Account ID";
    };
    DatabaseDirectory = mkOption {
      type = types.str;
      default = "/var/lib/GeoIP";
      description = "MaxMind Database Directory";
    };
    LicenseKey = mkOption {
      type = types.str;
      default = "/var/src/secrets/maxmind/maxmind_license_key";
      description = "MaxMind License Key File";
    };
  };

  config = mkIf cfg.enable {

    # GeoIP will be updated weekly and the database will be stored in /var/lib/GeoIP
    # You need to create an account at https://www.maxmind.com/en/geolite2/signup
    # and get a license key.
    # The license key needs to be stored in a file at /var/src/secrets/maxmind/maxmind_license_key.
    services.geoipupdate = {
      enable = true;
      interval = "weekly";
      settings = {
        EditionIDs = [
          "GeoLite2-Country"
        ];
        AccountID = cfg.AccountID;
        DatabaseDirectory = cfg.DatabaseDirectory;
        LicenseKey = cfg.LicenseKey;
      };
    };

    # when services.nginx.enable is set to true, we want to build nginx with the geoip2 module
    services.nginx = {
      package = pkgs.nginxStable.override (oldAttrs: rec{
        modules = with pkgs.nginxModules;[ geoip2 ];
        buildInputs = oldAttrs.buildInputs ++ [ pkgs.libmaxminddb ];
      });

      appendHttpConfig = toString
        (
          [
            # we want to load the geoip2 module in our http config, pointing to the database we are using
            # country iso code is the only data we need
            ''
              geoip2 ${config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-Country.mmdb {
                $geoip2_data_country_iso_code country iso_code;
              }
            ''
            # we want to allow only requests from Germany
            # if a request is not from Germany, we return no, which will result in a 403
            ''
              map $geoip2_data_country_iso_code $allowed_country {
                default no;
                DE yes;
              }
            ''
          ]
        );
    };

  };
}
