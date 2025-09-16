# --------------------------
# Stage 1: Build dependencies
# --------------------------
FROM node:22.16.0-alpine3.20 AS build

USER root

ARG LIBDE265_VERSION=1.0.15
ARG LIBHEIF_VERSION=1.18.2
ARG VIPS_VERSION=8.15.3

ENV LIBDE265_VERSION=$LIBDE265_VERSION \
    LIBHEIF_VERSION=$LIBHEIF_VERSION \
    VIPS_VERSION=$VIPS_VERSION \
    LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# Base tools
RUN apk add --no-cache \
    bash curl git make gcc g++ python3 cmake \
    autoconf automake libtool meson ninja \
    pkgconfig glib-dev expat-dev tiff-dev libjpeg-turbo-dev \
    libpng-dev libexif-dev libgsf-dev zlib-dev

# --------------------------
# Build libde265
# --------------------------
RUN curl -L https://github.com/strukturag/libde265/releases/download/v${LIBDE265_VERSION}/libde265-${LIBDE265_VERSION}.tar.gz \
    | tar zx && \
    cd libde265-${LIBDE265_VERSION} && \
    ./autogen.sh && \
    ./configure && \
    make -j$(nproc) && make install && \
    cd .. && rm -rf libde265-${LIBDE265_VERSION}

# --------------------------
# Build x265
# --------------------------
RUN git clone https://bitbucket.org/multicoreware/x265_git.git && \
    cd x265_git/build/linux && \
    cmake ../../source && \
    make -j$(nproc) && make install && \
    cd ../../.. && rm -rf x265_git

# --------------------------
# Build libheif
# --------------------------
RUN curl -L https://github.com/strukturag/libheif/releases/download/v${LIBHEIF_VERSION}/libheif-${LIBHEIF_VERSION}.tar.gz \
    | tar zx && \
    cd libheif-${LIBHEIF_VERSION} && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DWITH_X265=ON \
          -DWITH_DE265=ON \
          -DWITH_AOM=ON \
          -DWITH_DAV1D=ON \
          -DENABLE_PLUGIN_LOADING=NO .. && \
    make -j$(nproc) && make install && \
    cd ../.. && rm -rf libheif-${LIBHEIF_VERSION}

# --------------------------
# Build libvips
# --------------------------
RUN curl -L https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.xz \
    | tar -xJ && \
    cd vips-${VIPS_VERSION} && \
    meson setup build --buildtype=release && \
    meson compile -C build && \
    meson install -C build && \
    cd .. && rm -rf vips-${VIPS_VERSION}

# --------------------------
# Stage 2: App build
# --------------------------
FROM node:22.16.0-alpine3.20 AS app

USER root
WORKDIR /app

COPY --from=build /usr/local /usr/local
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# Dependencies for runtime
RUN apk add --no-cache \
    glib libjpeg-turbo tiff libpng libexif zlib

# Copy package files
COPY package*.json ./

# Install and rebuild sharp against local libvips
RUN npm install --build-from-source && \
    npm rebuild sharp --build-from-source

# Copy source
COPY . .

# Build NestJS
RUN npm run build

EXPOSE 3000

CMD ["node", "dist/main"]
