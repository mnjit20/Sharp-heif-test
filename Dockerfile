FROM node:22.16.0-alpine3.20 AS base

USER root

ARG LIBDE265_VERSION=1.0.15
ENV LIBDE265_VERSION=$LIBDE265_VERSION

ARG LIBHEIF_VERSION=1.18.2
ENV LIBHEIF_VERSION=$LIBHEIF_VERSION

ARG VIPS_VERSION=8.15.3
ENV VIPS_VERSION=$VIPS_VERSION

RUN apk add --no-cache \
    make gcc g++ python3 git nodejs npm zip

RUN apk add --no-cache \
    cmake autoconf automake libtool meson ninja curl \
    pkgconfig glib-dev expat-dev tiff-dev libjpeg-turbo-dev libgsf libexif libpng-dev cgif libjxl libimagequant

# Install libwebp
RUN git clone https://chromium.googlesource.com/webm/libwebp && \
    cd libwebp && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf libwebp

# Install x265
RUN git clone https://bitbucket.org/multicoreware/x265_git.git && \
    cd x265_git && \
    cmake source && \
    make && \
    cd .. && \
    rm -rf x265_git

# Install libde265
RUN curl -L https://github.com/strukturag/libde265/releases/download/v${LIBDE265_VERSION}/libde265-${LIBDE265_VERSION}.tar.gz | \
    tar zx && \
    cd libde265-${LIBDE265_VERSION} && \
    ./autogen.sh && \
    ./configure && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make && \
    make install && \
    cd ../.. && \
    rm -rf libde265-${LIBDE265_VERSION}

# Install libheif
RUN curl -L https://github.com/strukturag/libheif/releases/download/v${LIBHEIF_VERSION}/libheif-${LIBHEIF_VERSION}.tar.gz | \
    tar zx && \
    cd libheif-${LIBHEIF_VERSION} && \
    mkdir build && \
    cd build && \
    cmake -DENABLE_PLUGIN_LOADING=NO --preset=release .. && \
    make && \
    make install && \
    cd ../.. && \
    rm -rf libheif-${LIBHEIF_VERSION}

# Install libvips
RUN curl -L https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.xz | \
    tar -xJ && \
    cd vips-${VIPS_VERSION} && \
    meson setup build && \
    cd build && \
    meson compile && \
    meson test && \
    meson install && \
    cd ../.. && \
    rm -rf vips-${VIPS_VERSION}

WORKDIR /app

COPY . .

COPY package.json package-lock.json ./

RUN npm install --build-from-source

EXPOSE 3000

CMD ["npm", "start"]
