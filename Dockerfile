FROM centos:6.6


RUN sed -Ei 's/mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/* && \
	sed -Ei 's/#baseurl=http:\/\/mirror.centos.org/baseurl=http:\/\/archive.kernel.org\/centos-vault/g' /etc/yum.repos.d/*

RUN yum -y update && yum -y install \
	bzip2 \
	bzip2-devel \
	fuse-devel \
	gcc \
	git \
	glibc-static \
	libacl \
	libacl-devel \
	libffi-devel \
	libuuid \
	libuuid-devel \
	make \
	pcre-devel \
	perl-core \
	sqlite-devel \
	tar \
	unzip \
	wget \
	zlib-devel && yum -y clean all

WORKDIR /lzma
RUN wget --no-check-certificate -q https://tukaani.org/xz/xz-5.2.7.tar.bz2 && \
	tar xf xz-5.2.7.tar.bz2
WORKDIR xz-5.2.7
RUN ./configure --enable-shared --prefix=/usr && make -j"$(nproc)" && make install

WORKDIR /openssl

ENV OPENSSL_VER "1.1.1q"
RUN wget --no-check-certificate -q https://ftp.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz && \
	tar xf openssl-${OPENSSL_VER}.tar.gz

WORKDIR openssl-${OPENSSL_VER}

RUN ./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib no-shared && make -j"$(nproc)" && make install
ENV LD_LIBRARY_PATH "/usr/local/lib:/usr/local/lib64:/usr/lib:/usr/lib64:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH "/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH"


WORKDIR /zstd

ENV ZSTD_VER "1.5.2"
RUN wget --no-check-certificate -q https://github.com/facebook/zstd/releases/download/v${ZSTD_VER}/zstd-${ZSTD_VER}.tar.gz && \
	tar xf zstd-${ZSTD_VER}.tar.gz
WORKDIR zstd-${ZSTD_VER}
RUN make -j "$(nproc)" && make install

ENV PKG_CONFIG_PATH "/zstd/zstd-${ZSTD_VER}/lib:$PKG_CONFIG_PATH"
ENV LD_LIBRARY_PATH "/zstd/zstd-${ZSTD_VER}/lib:$LD_LIBRARY_PATH"

WORKDIR /xxhash
RUN wget --no-check-certificate -q https://github.com/Cyan4973/xxHash/archive/refs/tags/v0.8.1.zip && \
	unzip v0.8.1.zip
WORKDIR xxHash-0.8.1
RUN make -j "$(nproc)" && make install

WORKDIR /lz4
RUN wget --no-check-certificate -q https://github.com/lz4/lz4/archive/refs/tags/v1.9.4.zip && \
	unzip v1.9.4.zip
WORKDIR lz4-1.9.4
RUN make -j $(nproc) && make install


WORKDIR /python

ENV PY_VER "3.10.8"
RUN wget --no-check-certificate -q https://www.python.org/ftp/python/${PY_VER}/Python-${PY_VER}.tar.xz && \
	tar xf Python-${PY_VER}.tar.xz

WORKDIR Python-${PY_VER}

RUN ./configure --prefix=/usr --enable-shared && make -j "$(nproc)" && make install

RUN ldconfig

RUN mv /usr/bin/python /usr/bin/python-old && mv /usr/bin/pip /usr/bin/pip-old || true
RUN ln -s /usr/bin/python3.10 /usr/bin/python
RUN ln -s /usr/bin/pip3.10 /usr/bin/pip

RUN pip install  --no-cache-dir --upgrade pip setuptools wheel && \
	pip install --no-cache-dir pyinstaller && \
	pip install --no-cache-dir --no-binary=scons scons && \
	pip install  --no-cache-dir --no-binary=staticx staticx && \
	pip install  --no-cache-dir patchelf

WORKDIR /borg

RUN git clone https://github.com/borgbackup/borg

WORKDIR borg
RUN git fetch --all --tags && \
	git checkout tags/1.2.2 -b latest

RUN echo "cryptography<3.4" >> requirements.d/development.lock.txt
RUN pip install --no-cache-dir -r requirements.d/development.lock.txt
RUN python3 setup.py clean && \
	python3 setup.py clean2

RUN pip install --no-cache-dir -e '.[fuse]'

RUN pyinstaller --clean --distpath=/borg/built scripts/borg.exe.spec

WORKDIR /borgmatic

ENV BORGMATIC_VER "1.7.2"
RUN git clone https://github.com/necessary129/borgmatic-binary
WORKDIR borgmatic-binary
RUN sed -Ei "s/VERSION := 1.7.2/VERSION := ${BORGMATIC_VER}/" Makefile
RUN make all



WORKDIR /finalbuilds
RUN staticx /borg/built/borg.exe ./borg && \
	staticx /borgmatic/borgmatic-binary/borgmatic-${BORGMATIC_VER}/dist/borgmatic ./borgmatic && \
	staticx /borgmatic/borgmatic-binary/borgmatic-${BORGMATIC_VER}/dist/generate-borgmatic-config ./generate-borgmatic-config && \
	staticx /borgmatic/borgmatic-binary/borgmatic-${BORGMATIC_VER}/dist/upgrade-borgmatic-config ./upgrade-borgmatic-config && \
	staticx /borgmatic/borgmatic-binary/borgmatic-${BORGMATIC_VER}/dist/validate-borgmatic-config ./validate-borgmatic-config