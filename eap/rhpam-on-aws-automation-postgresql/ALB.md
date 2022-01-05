## Validating Application Load Balancer configurations

|Listener|Target|Result|
|---|---|---|
|HTTP:80|http1-http-bc-8080|OK|
|HTTPS:8443|http1-http-bc-8080|Needs Redirect HTTP:80->HTTP:443<br/>Problem was: "location: http:/..."<br/>Need port HTTP:80 open on `Security Group`|
|HTTP:80|http2-http-bc-8080|Not supported<br/>Problem was: "Listener protocol 'HTTP' is not supported with a target group with the protocol-version 'HTTP2'"|
|HTTPS:8443|http2-http-bc-8080|Not working<br/>Problem was: "location: http://default-host:8080/business-central/"<br/>TO BE INVESTIGATED (SSL certificate?)|
|HTTPS:8443|http1-https-bc-8443|OK<br/>After login, it remains on https|
|HTTPS:8443|http2-https-bc-8443|Not working<br/>Problem was: "location: http://default-host:8080/business-central/"<br/>TO BE INVESTIGATED (SSL certificate?)|

Proposed solution:
* External acces through HTTPS:8443
* Internal forward to HTTP:8080
* Needs Redirect rule HTTP:80->HTTP:443
* Needs port HTTP:80 open on `Security Group`

### Diagnostic Utilities
This utility can be used to monitor data traffic and dump to a file (excluding ssh and KS and EFS sessions), from any 
active server:
```shell
sudo yum install -y tcpdump
sudo tcpdump -Al -i eth0 port not 22 and host not 10.0.1.30 and host not 10.0.1.92 | tee data
```

To debug the ALB for a given application (e.g., `business-central`) you can run curl as follows:
```shell
curl -kLv --user <UAER>:<PASSWORD> https://<ALB HOST>>/business-central
```

## Investigation of `default-host` issue
Answer when not working:
```shell
> GET /business-central HTTP/2
> Host: test-rhpam-bc-1403588523.us-east-1.elb.amazonaws.com
> authorization: Basic cmhwYW1hZG1pbjpyZWRoYXQxMjMj
> user-agent: curl/7.77.0
> accept: */*
> 
* Connection state changed (MAX_CONCURRENT_STREAMS == 128)!
< HTTP/2 302 
< server: awselb/2.0
< date: Wed, 05 Jan 2022 10:16:26 GMT
< content-length: 0
< location: http://default-host:8080/business-central/
```
Note the **server: awselb/2.0** part in the response

When working (no redirect):
```shell
> GET /business-central HTTP/2
> Host: test-rhpam-bc-1403588523.us-east-1.elb.amazonaws.com
> authorization: Basic cmhwYW1hZG1pbjpyZWRoYXQxMjMj
> user-agent: curl/7.77.0
> accept: */*
> 
* Connection state changed (MAX_CONCURRENT_STREAMS == 128)!
< HTTP/2 302 
< date: Wed, 05 Jan 2022 10:23:49 GMT
< content-length: 0
< location: https://test-rhpam-bc-1403588523.us-east-1.elb.amazonaws.com/business-central/
< 
* Connection #0 to host test-rhpam-bc-1403588523.us-east-1.elb.amazonaws.com left intact
* Issue another request to this URL: 'https://test-rhpam-bc-1403588523.us-east-1.elb.amazonaws.com/business-central/'
* Found bundle for host test-rhpam-bc-1403588523.us-east-1.elb.amazonaws.com: 0x600003b4c030 [can multiplex]
* Re-using existing connection! (#0) with host test-rhpam-bc-1403588523.us-east-1.elb.amazonaws.com
* Connected to test-rhpam-bc-1403588523.us-east-1.elb.amazonaws.com (3.218.233.35) port 443 (#0)
* Server auth using Basic with user 'rhpamadmin'
* Using Stream ID: 3 (easy handle 0x7fd71c00ca00)
> GET /business-central/ HTTP/2
> Host: test-rhpam-bc-1403588523.us-east-1.elb.amazonaws.com
> authorization: Basic cmhwYW1hZG1pbjpyZWRoYXQxMjMj
> user-agent: curl/7.77.0
> accept: */*
> 
< HTTP/2 302 
< date: Wed, 05 Jan 2022 10:23:49 GMT
< content-type: text/html
< content-length: 0
< location: https://test-rhpam-bc-1403588523.us-east-1.elb.amazonaws.com/business-central/login?
< expires: Thu, 01 Jan 1970 00:00:00 GMT
< cache-control: no-cache, no-store, must-revalidate
< x-powered-by: JSP/2.3
< set-cookie: JSESSIONID=_SUwfCKElYYlxt_q3TBTTJ9DXe-SJ0x7YXvIrRxC.ip-10-0-1-48; path=/business-central; HttpOnly
< x-xss-protection: 1; mode=block
< pragma: no-cache
< x-frame-options: SAMEORIGIN
```