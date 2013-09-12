sub vcl_fetch {
#FASTLY fetch

    if ((beresp.status == 302 || beresp.status == 303) &&
        (beresp.http.Location ~ "www\.rubygems\.org" ||
         beresp.http.Location ~ "s3\.amazonaws\.com")) {
        set req.url = regsub(beresp.http.Location,"^https://[^/]+(/.*)","\1");
        restart;
    }
}
