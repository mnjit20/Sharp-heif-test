# --------------------------
# Stage: build (compile libs + install dependencies)
# --------------------------
FROM node:22.16.0-alpine3.20 AS build

ARG LIBDE265_VERSION=1.0.15
ARG LIBHEIF_VERSION=1.18.2
ARG VIPS_VERSION=8.15.3

# Environment variables
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig
ENV PATH=/usr/local/bin:$PATH
WORKDIR /app

# Install build tools and dependencies
RUN apk add --no-cache \
    bash curl git build-base python3 python3-dev make cmake \
    autoconf automake libtool meson ninja pkgconfig glib-dev expat-dev \
    tiff-dev libjpeg-turbo-dev libpng-dev libexif-dev libgsf-dev zlib-dev \
    linux-headers nasm yasm coreutils file

# Make sure node-gyp can find "python"
RUN ln -sf /usr/bin/python3 /usr/bin/python

# --------------------------
# Build x265 (fixed version)
# --------------------------
RUN apk add --no-cache --virtual .build-deps-cmake cmake && \
    git clone --depth 1 https://bitbucket.org/multicoreware/x265_git.git && \
    cd x265_git && \
    # Clean up any existing build directory
    rm -rf build && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_SHARED=ON ../source && \
    make -j$(nproc) && make install && \
    cd /app && rm -rf x265_git && \
    apk del .build-deps-cmake

# --------------------------
# Build libde265
# --------------------------
RUN curl -L https://github.com/strukturag/libde265/releases/download/v${LIBDE265_VERSION}/libde265-${LIBDE265_VERSION}.tar.gz \
    | tar zx && \
    cd libde265-${LIBDE265_VERSION} && \
    ./autogen.sh && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && make install && \
    cd .. && rm -rf libde265-${LIBDE265_VERSION}

# --------------------------
# Build libheif
# --------------------------
RUN curl -L https://github.com/strukturag/libheif/releases/download/v${LIBHEIF_VERSION}/libheif-${LIBHEIF_VERSION}.tar.gz \
    | tar zx && \
    cd libheif-${LIBHEIF_VERSION} && mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DWITH_X265=ON \
          -DWITH_DE265=ON \
          -DENABLE_PLUGIN_LOADING=NO .. && \
    make -j$(nproc) && make install && \
    cd /app && rm -rf libheif-${LIBHEIF_VERSION}

# --------------------------
# Build libvips
# --------------------------
RUN apk add --no-cache libwebp-dev orc-dev fftw-dev && \
    curl -L https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.xz \
    | tar -xJ && \
    cd vips-${VIPS_VERSION} && \
    meson setup build --buildtype=release --prefix=/usr/local && \
    meson compile -C build && \
    meson install -C build && \
    cd /app && rm -rf vips-${VIPS_VERSION}

# --------------------------
# Install Node dependencies
# --------------------------
COPY package*.json ./

# Environment for sharp build
ENV npm_config_build_from_source=true

# Install dependencies
RUN npm ci --unsafe-perm

# Copy source and build
COPY . .
RUN npm run build && \
    npm prune --production

# --------------------------
# Stage: runtime
# --------------------------
FROM node:22.16.0-alpine3.20 AS runtime

# Environment variables
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV NODE_ENV=production
WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    glib \
    libjpeg-turbo \
    tiff \
    libpng \
    libexif \
    zlib \
    libwebp \
    libgcc \
    libstdc++ \
    expat

# Copy compiled libraries and application
COPY --from=build /usr/local/lib /usr/local/lib
COPY --from=build /usr/local/bin /usr/local/bin
COPY --from=build /usr/local/include /usr/local/include
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package*.json ./

# Create necessary directories and fix permissions
RUN mkdir -p /tmp && chmod 1777 /tmp

EXPOSE 3000
USER node
CMD ["node", "dist/main"]