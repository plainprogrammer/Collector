# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal, or build it by hand as README.md's
# "Building from source" says, passing the build facts at the end of this file (spec 084), and then run it:
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name collector collector:local

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.7
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl imagemagick libjemalloc2 libvips sqlite3 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libvips libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Fetch and verify the pinned OCR engine for the card scanner (spec 007, ADR 0001).
RUN bin/fetch-ocr-engine

# Art matching decodes Scryfall's small images with ImageMagick (spec 011, ADR 0012).
RUN command -v magick || command -v convert

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile




# Final stage for app image
FROM base

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Thruster refuses request bodies over 40 MB, as Puma does (spec 025 decision 6).
ENV MAX_REQUEST_BODY="40000000"

# The build facts the footer's licence line shows (spec 084): the version, the full commit SHA and the https address of
# that commit's source. CI passes them (docs/releasing.md); a build by hand passes them with --build-arg. Declared last,
# so these values, which change with every commit, invalidate no earlier layer. Without them the footer reads "unknown
# version" and bin/image-smoke fails.
ARG COLLECTOR_VERSION=""
ARG COLLECTOR_REVISION=""
ARG COLLECTOR_SOURCE_URL=""
ENV COLLECTOR_VERSION="${COLLECTOR_VERSION}" \
    COLLECTOR_REVISION="${COLLECTOR_REVISION}" \
    COLLECTOR_SOURCE_URL="${COLLECTOR_SOURCE_URL}"

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
