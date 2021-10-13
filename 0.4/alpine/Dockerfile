# Build stage for BerkeleyDB
FROM alpine as berkeleydb

RUN sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories
RUN apk --no-cache add autoconf
RUN apk --no-cache add automake
RUN apk --no-cache add build-base
RUN apk --no-cache add libressl

ENV BERKELEYDB_VERSION=db-4.8.30.NC
ENV BERKELEYDB_PREFIX=/opt/${BERKELEYDB_VERSION}

RUN wget https://download.oracle.com/berkeley-db/${BERKELEYDB_VERSION}.tar.gz
RUN tar -xzf *.tar.gz
RUN sed s/__atomic_compare_exchange/__atomic_compare_exchange_db/g -i ${BERKELEYDB_VERSION}/dbinc/atomic.h
RUN mkdir -p ${BERKELEYDB_PREFIX}

WORKDIR /${BERKELEYDB_VERSION}/build_unix

RUN ../dist/configure --enable-cxx --disable-shared --with-pic --prefix=${BERKELEYDB_PREFIX}
RUN make -j`nproc`
RUN make install
RUN rm -rf ${BERKELEYDB_PREFIX}/docs

# Build stage for Boost
FROM alpine as boost

COPY --from=berkeleydb /opt /opt

RUN sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories
RUN apk --no-cache add openssl
RUN apk --no-cache add linux-headers
RUN apk --no-cache add build-base
RUN apk --no-cache add git

ENV BOOST_VERSION=1.64.0
ENV BOOST_PREFIX=/opt/boost-${BOOST_VERSION}

RUN wget http://downloads.sourceforge.net/project/boost/boost/${BOOST_VERSION}/boost_${BOOST_VERSION//./_}.tar.gz
RUN tar -xzf *.tar.gz
RUN mkdir -p ${BOOST_PREFIX}
RUN mv "boost_${BOOST_VERSION//./_}" /boost-${BOOST_VERSION}

WORKDIR /boost-${BOOST_VERSION}

RUN ./bootstrap.sh --prefix=${BOOST_PREFIX}
RUN ./b2 -j `nproc` install

# Build stage for RavenDark Core
FROM alpine as ravendark-core

COPY --from=boost /opt /opt

RUN sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories
RUN apk --no-cache add autoconf
RUN apk --no-cache add automake
RUN apk --no-cache add build-base
RUN apk --no-cache add chrpath
RUN apk --no-cache add file
RUN apk --no-cache add gnupg
RUN apk --no-cache add libevent-dev
RUN apk --no-cache add libressl
RUN apk --no-cache add libtool
RUN apk --no-cache add linux-headers
RUN apk --no-cache add zeromq-dev
RUN apk --no-cache add git
RUN apk --no-cache add openssl-dev

ENV RAVENDARK_VERSION=0.4.3
ENV RAVENDARK_PREFIX=/opt/ravendark-${RAVENDARK_VERSION}

RUN git clone https://github.com/raven-dark/raven-dark.git /ravendark-${RAVENDARK_VERSION} \
    && cd /ravendark-${RAVENDARK_VERSION} \
    && git checkout ${RAVENDARK_VERSION}

WORKDIR /ravendark-${RAVENDARK_VERSION}

RUN sed -i '/AC_PREREQ/a\AR_FLAGS=cr' src/univalue/configure.ac
RUN sed -i '/AX_PROG_CC_FOR_BUILD/a\AR_FLAGS=cr' src/secp256k1/configure.ac
RUN sed -i s:sys/fcntl.h:fcntl.h: src/compat.h

RUN ./autogen.sh
RUN ./configure LDFLAGS="-L`ls -d /opt/db*`/lib/ -L`ls -d /opt/boost*`/lib/" \
    CPPFLAGS="-I`ls -d /opt/db*`/include/ -I`ls -d /opt/boost*`/include/" \
    --with-boost-libdir="`ls -d /opt/boost*`/lib/" \
    --prefix=${RAVENDARK_PREFIX} \
    --mandir=/usr/share/man \
    --disable-tests \
    --disable-bench \
    --disable-ccache \
    --with-gui=no \
    --with-utils \
    --with-libs \
    --with-daemon
RUN make -j`nproc`
RUN make install
RUN strip ${RAVENDARK_PREFIX}/bin/ravendark-cli
#RUN strip ${RAVENDARK_PREFIX}/bin/ravendark-tx
RUN strip ${RAVENDARK_PREFIX}/bin/ravendarkd
RUN strip ${RAVENDARK_PREFIX}/lib/libravendarkconsensus.a
RUN strip ${RAVENDARK_PREFIX}/lib/libravendarkconsensus.so.0.0.0

# Build stage for compiled artifacts
FROM alpine

RUN adduser -S ravendark
RUN sed -i 's/http\:\/\/dl-cdn.alpinelinux.org/https\:\/\/alpine.global.ssl.fastly.net/g' /etc/apk/repositories
RUN apk --no-cache add \
  libevent \
  libzmq \
  su-exec

ENV RAVENDARK_DATA=/home/ravendark/.ravendark
ENV RAVENDARK_VERSION=0.4.3
ENV RAVENDARK_PREFIX=/opt/ravendark-${RAVENDARK_VERSION}
ENV BOOST_VERSION=1.64.0
ENV BOOST_PREFIX=/opt/boost-${BOOST_VERSION}
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${BOOST_PREFIX}/lib
ENV PATH=${RAVENDARK_PREFIX}/bin:$PATH

COPY --from=ravendark-core /opt /opt
COPY docker-entrypoint.sh /entrypoint.sh

VOLUME ["/home/ravendark/.ravendark"]

EXPOSE 8757 18757 8756 18756 

RUN ["chmod", "+x", "/entrypoint.sh"]

ENTRYPOINT ["/entrypoint.sh"]

RUN ravendarkd -version | grep "RavenDark Core Daemon version v${RAVENDARK_VERSION}"

CMD ["ravendarkd"]