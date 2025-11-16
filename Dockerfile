FROM ubuntu:24.04

COPY mako mako.zip /barracuda/
WORKDIR /barracuda

ENTRYPOINT ["/barracuda/mako"]
