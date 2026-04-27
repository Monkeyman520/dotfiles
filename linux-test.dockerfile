FROM ubuntu:24.04 AS builder

RUN apt-get update -y && \
    apt-get install -y ca-certificates wget curl

