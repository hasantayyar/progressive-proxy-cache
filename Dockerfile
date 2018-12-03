FROM alpine:3.8 as builder

WORKDIR /apps/

ENV SQUID_VER_URL=http://www.squid-cache.org/Versions/v3/3.5/squid-3.5.27.tar.gz \
  SQUID_PID=/var/run/squid/squid.pid

# TODO signature check for downloaded package
RUN set -x && \
  apk add --no-cache  \
  gcc g++ libc-dev \
  curl gnupg \
  libressl-dev \
  perl-dev \
  autoconf automake make \
  pkgconfig heimdal-dev \
  libtool libcap-dev linux-headers

RUN set -x && \
  mkdir -p /tmp/build && \
  cd /tmp/build && \
  curl -SsL $SQUID_VER_URL -o squid.tar.gz 

RUN set -x && \
  cd /tmp/build && \	
  tar --strip 1 -xzf squid.tar.gz && \
  CFLAGS="-g0 -O2" \
  CXXFLAGS="-g0 -O2" \
  LDFLAGS="-s" \
  \
  ./configure --prefix=/apps/squid \
  --build="$(uname -m)" \
  --host="$(uname -m)" \
  --disable-strict-error-checking --disable-arch-native \
  --enable-icap-client \
  --enable-auth --enable-basic-auth-helpers="NCSA" \
  --enable-http-violations \
  --enable-removal-policies="lru,heap" \
  --enable-auth-digest \
  --enable-epoll \
  --enable-silent-rules \
  --disable-mit \
  --enable-heimdal \
  --enable-delay-pools \
  --enable-arp-acl \
  --enable-openssl --enable-ssl --enable-ssl-crtd \
  --with-large-files --with-default-user=squid --with-openssl --with-pidfile=${SQUID_PID}

RUN set -x && \
  cd /tmp/build && \
  make -j $(grep -cs ^processor /proc/cpuinfo) && \
  make install

###############

FROM alpine:3.8

ENV SQUID_CACHE_DIR=/cache \
  SQUID_LOG_DIR=/var/log/squid \
  SQUID_USER=squid \
  SQUID_CONFIG_FILE=/apps/squid.conf \
  SQUID_BIN=/apps/squid/sbin/squid \
  SQUID_PID=/var/run/squid/squid.pid

ADD . /apps/

COPY --from=builder /apps/squid /apps/squid/
RUN apk update && apk add libressl-dev libgcc libstdc++ libcap libltdl

RUN set -x && \
  deluser ${SQUID_USER} 2>/dev/null; delgroup ${SQUID_USER} 2>/dev/null; \
  addgroup -S ${SQUID_USER} -g 3128 \
  && adduser -S -u 3128 -G ${SQUID_USER} -g ${SQUID_USER} -H -D -s /bin/false -h ${SQUID_CACHE_DIR} ${SQUID_USER}

RUN mkdir -p ${SQUID_LOG_DIR}

RUN mkdir -p ${SQUID_CACHE_DIR}

RUN mkdir -p /apps/squid/var/lib/
RUN /apps/squid/libexec/ssl_crtd -c -s /apps/squid/var/lib/ssl_db -M 4MB

RUN mkdir -p /var/run/squid && touch ${SQUID_PID} \
  && chmod -R 755 ${SQUID_PID} \
  && chown ${SQUID_USER}:${SQUID_USER} ${SQUID_PID}
    
RUN chmod -R 755 ${SQUID_LOG_DIR} \
  && chown -R ${SQUID_USER}:${SQUID_USER} ${SQUID_CACHE_DIR} \
  && chown -R ${SQUID_USER}:${SQUID_USER} /apps/

EXPOSE 3128/tcp
USER squid
RUN echo "Starting squid proxy.... Pid file: $SQUID_PID"
CMD ["sh", "-c", "${SQUID_BIN} -N -f ${SQUID_CONFIG_FILE} -z && exec ${SQUID_BIN} -f ${SQUID_CONFIG_FILE} -NYCd 1"]

