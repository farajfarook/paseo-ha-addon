# Ingress adapter template (design D3). Rendered by /etc/paseo-ha/init.d/50-nginx.sh
# into /etc/nginx/http.d/paseo.conf by nginx/render.js, which substitutes four
# tokens written below as UPSTREAM_AUTH_HTTP, WS_PROTOCOLS_MAP and
# WS_PROTOCOLS_HEADER (direct-port password only) and SERVER_ID (the daemon's
# server ID, read by the shim to heal a stale host) between at-signs. Never write
# those tokens with the at-signs inside a comment: the substitution is global
# and would inject multi-line config into the comment.

# The shim tag is injected before </head> in HTML only. The same sub_filter also
# runs on the JS bundle, which embeds an HTML page (mermaidRuntimeHtml) inside a
# string literal; inserting a tag with quotes there is a syntax error.
map $sent_http_content_type $paseo_shim_tag {
    default "";
    ~*^text/html "<script src=\"$http_x_ingress_path/paseo-ha/shim.js\" data-paseo-server-id=\"@SERVER_ID@\"></script>";
}

map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
@WS_PROTOCOLS_MAP@
server {
    listen 8099 default_server;
    server_name _;

    # Only the Home Assistant ingress proxy may talk to us.
    allow 172.30.32.2;
    deny all;

    client_max_body_size 100m;

    # Add-on-owned static assets. HA strips the ingress prefix before
    # forwarding, so the browser's <prefix>/paseo-ha/shim.js arrives here as
    # /paseo-ha/shim.js.
    location /paseo-ha/ {
        alias /opt/paseo-ha/www/;
        add_header Cache-Control "no-store" always;
        try_files $uri =404;
    }

    location / {
        proxy_pass http://127.0.0.1:6767;
        proxy_http_version 1.1;

        # The daemon's host allowlist and same-origin checks run against Host,
        # so it must always see the loopback listen address, never the browser's.
        proxy_set_header Host 127.0.0.1:6767;
        proxy_set_header Origin http://127.0.0.1:6767;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto http;

        # sub_filter needs uncompressed bodies.
        proxy_set_header Accept-Encoding "";

        proxy_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
@UPSTREAM_AUTH_HTTP@
@WS_PROTOCOLS_HEADER@

        sub_filter_once off;
        sub_filter_types application/javascript application/json text/css;

        # Prefix root-absolute asset URLs with the ingress prefix. The prefix
        # comes from the X-Ingress-Path header the HA ingress proxy adds to
        # every request. Without the header (direct loopback access) the empty
        # prefix keeps URLs working as-is.
        sub_filter '"/_expo/' '"$http_x_ingress_path/_expo/';
        sub_filter '"/assets/' '"$http_x_ingress_path/assets/';
        sub_filter '`/assets/' '`$http_x_ingress_path/assets/';
        sub_filter '"/manifest.json"' '"$http_x_ingress_path/manifest.json"';
        sub_filter '"/favicon.ico"' '"$http_x_ingress_path/favicon.ico"';
        sub_filter '"/apple-touch-icon.png"' '"$http_x_ingress_path/apple-touch-icon.png"';
        sub_filter '"/pwa-icon-192.png"' '"$http_x_ingress_path/pwa-icon-192.png"';
        sub_filter '"/pwa-icon-512.png"' '"$http_x_ingress_path/pwa-icon-512.png"';
        sub_filter '"start_url": "/"' '"start_url": "$http_x_ingress_path/"';

        # Run the ingress shim before the app bundle. The daemon injects its
        # connection hint directly before </head>, so the shim ends up after it
        # and can override the hint (see shim.js).
        sub_filter '</head>' '$paseo_shim_tag</head>';
    }
}