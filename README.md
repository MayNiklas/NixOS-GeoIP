# NixOS-GeoIP

Easily make GeoIP databases available to use with NGINX.

Since I want to use GeoIP on personal as well as work projects, I decided to put this module into it's own flake repository.
It might be helpful to others as well.
Currently only filtering for Germany is supported; more is planned.

## Usage

### NixOS

1. Add this repository as a flake input to your project:

```nix
{
  inputs.GeoIP={
    url = "github:MayNiklas/NixOS-GeoIP";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

2. Enable the service in your configuration.nix:

```nix
{ GeoIP, ... }: {

  imports = [ GeoIP.nixosModules.geoip ];

  mayniklas.geoip = {
    enable = true;
    AccountID = 123456;
    DatabaseDirectory = "/var/lib/GeoIP";
    LicenseKey = "/var/src/secrets/maxmind/maxmind_license_key"
  };
}
```


3. Create the LicenseKey file and add your license key to it:

```bash
sudo mkdir -p /var/src/secrets/maxmind
sudo touch /var/src/secrets/maxmind/maxmind_license_key
sudo nano /var/src/secrets/maxmind/maxmind_license_key
```

4. To filter for Germany, configure your virtualHost like this:

```nix
{
  services.nginx = {
    virtualHosts = {
      ${cfg.hostname} = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            extraConfig = toString ([''
              proxy_set_header X-Forwarded-Host $http_host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-Proto $scheme;
            ''] ++ optional config.services.geoipupdate.enable ''
              if ($allowed_country = no) {
                  return 444;
              }
            '');
          };
        };
      };
    };
  };
}
```

This will return a 444 status code if a request is made from a country other than Germany.
