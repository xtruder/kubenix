{ pkgs, dockerTools, lib, ... }:

with lib;

{
  nginx = let
    nginxPort = "80";
    nginxConf = pkgs.writeText "nginx.conf" ''
      user nginx nginx;
      daemon off;
      error_log /dev/stdout info;
      pid /dev/null;
      events {}
      http {
        access_log /dev/stdout;
        server {
          listen ${nginxPort};
          index index.html;
          location / {
            root ${nginxWebRoot};
          }
        }
      }
    '';
    nginxWebRoot = pkgs.writeTextDir "index.html" ''
      <html><body><h1>Hello from NGINX</h1></body></html>
    '';
  in dockerTools.buildLayeredImage {
    name = "xtruder/nginx";
    tag = "latest";
    contents = [pkgs.nginx];
    extraCommands = ''
      mkdir etc
      chmod u+w etc
      echo "nginx:x:1000:1000::/:" > etc/passwd
      echo "nginx:x:1000:nginx" > etc/group
    '';
    config = {
      Cmd = ["nginx" "-c" nginxConf];
      ExposedPorts = {
        "${nginxPort}/tcp" = {};
      };
    };
  };
}
