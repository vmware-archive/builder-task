# The idmap building and installing portion of this is copied verbatim from
# https://github.com/genuinetools/img/blob/master/Dockerfile, which notes:
#
#   We don't use the Alpine shadow pkg bacause:
#   1. Alpine shadow makes SUID `su` executable without password: https://github.com/gliderlabs/docker-alpine/issues/430
#      (but note that the SUID binary is not executable after unsharing the usernamespace. so this issue is not critical)
#   2. To allow running img in a container without CAP_SYS_ADMIN, we need to do either
#       a) install newuidmap/newgidmap with file capabilities rather than SETUID (requires kernel >= 4.14)
#       b) install newuidmap/newgidmap >= 20181125 (59c2dabb264ef7b3137f5edb52c0b31d5af0cf76)
#      We choose b) until kernel >= 4.14 gets widely adopted.
#      See https://github.com/shadow-maint/shadow/pull/132 https://github.com/shadow-maint/shadow/pull/138 https://github.com/shadow-maint/shadow/pull/141
FROM alpine:3.9 AS idmap
  RUN apk add --no-cache autoconf automake build-base byacc gettext gettext-dev gcc git libcap-dev libtool libxslt
  RUN git clone https://github.com/shadow-maint/shadow.git /shadow
  WORKDIR /shadow
  RUN git checkout 59c2dabb264ef7b3137f5edb52c0b31d5af0cf76
  RUN ./autogen.sh --disable-nls --disable-man --without-audit --without-selinux --without-acl --without-attr --without-tcb --without-nscd \
    && make \
    && cp src/newuidmap src/newgidmap /usr/bin

FROM alpine:3.9
  RUN apk add bash rsync jq curl git

  RUN curl -fSL "https://github.com/genuinetools/img/releases/download/v0.5.7/img-linux-amd64" -o "/usr/local/bin/img" \
    && echo "41aa98ab28be55ba3d383cb4e8f86dceac6d6e92102ee4410a6b43514f4da1fa  /usr/local/bin/img" | sha256sum -c - \
    && chmod a+x "/usr/local/bin/img"

  COPY --from=idmap /usr/bin/newuidmap /usr/bin/newuidmap
  COPY --from=idmap /usr/bin/newgidmap /usr/bin/newgidmap
  RUN chmod u+s /usr/bin/newuidmap /usr/bin/newgidmap \
    && adduser -D -u 1000 user \
    && mkdir -p /run/user/1000 \
    && chown -R user /run/user/1000 /home/user \
    && echo user:100000:65536 | tee /etc/subuid | tee /etc/subgid

  # USER user
  # ENV USER user
  # ENV HOME /home/user
  # ENV XDG_RUNTIME_DIR=/run/user/1000

  ADD build /usr/bin/build
  ENTRYPOINT ["build"]
