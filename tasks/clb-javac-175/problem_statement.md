Sending large ByteBuffers is broken
**Describe the bug**

per @kevink-sq 

we ran into response problems when using the jetty org.newsclub.net.unix.jetty.AFSocketServerConnector in version 2.6.2 in production. We were looking for alternatives to address the jnr-unixsocket load issue and tried junixsocket.

symptoms:

* when the jetty service using the AFSocketServerConnector returned a response greater than 32KB, the same first 32KB (exactly every 0x8000 bytes) was repeated. For example, if the response was 100KB, then the same first 32KB was repeated until 100KB.
* server did not log a warning or error and the request looked like a 200 response on the server side. Only when client attempted to parse the response was there an error (especially if it was supposed to be structured data).
* OS socket SO_SNDBUF was verified to be 212MB.
* Swapping out the connector to Jetty 10's UnixDomainServerConnector fixed the issue (note swapping the connector was the only diff in the server, no other changes/updates were present)

