# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t ai .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name ai ai

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.5
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages and Chrome dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libjemalloc2 \
    libvips \
    sqlite3 \
    wget \
    gnupg \
    unzip \
    xvfb \
    jq \
    fonts-liberation \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libxkbcommon0 \
    libxss1 \
    libgbm1 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Chrome using new key management (detect architecture)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/googlechrome-linux-keyring.gpg && \
        sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/googlechrome-linux-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' && \
        apt-get update && \
        apt-get install -y google-chrome-stable && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        echo "Chrome not available for $ARCH, installing Chromium instead" && \
        apt-get update && \
        apt-get install -y chromium chromium-driver && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Install ChromeDriver (skip for ARM64 if using Chromium)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        CHROME_VERSION=$(google-chrome --version | awk '{print $3}' | cut -d. -f1-3) && \
        echo "Chrome version: $CHROME_VERSION" && \
        CHROMEDRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/json/versions.json" | \
        jq -r ".versions[] | select(.version | startswith(\"$CHROME_VERSION\")) | .version" | head -1) && \
        echo "ChromeDriver version: $CHROMEDRIVER_VERSION" && \
        wget -q "https://storage.googleapis.com/chrome-for-testing-public/$CHROMEDRIVER_VERSION/linux64/chromedriver-linux64.zip" && \
        unzip chromedriver-linux64.zip && \
        mv chromedriver-linux64/chromedriver /usr/local/bin/chromedriver && \
        chmod +x /usr/local/bin/chromedriver && \
        rm -rf chromedriver-linux64* && \
        chromedriver --version; \
    else \
        echo "Using Chromium driver for $ARCH - already installed with chromium-driver package" && \
        ln -s /usr/bin/chromedriver /usr/local/bin/chromedriver 2>/dev/null || \
        ln -s /usr/lib/chromium/chromedriver /usr/local/bin/chromedriver 2>/dev/null || \
        echo "ChromeDriver symlink setup complete"; \
    fi

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    CHROMEDRIVER_PATH="/usr/local/bin/chromedriver"

# Set Chrome binary path based on what was installed
RUN if [ -f "/usr/bin/google-chrome-stable" ]; then \
        echo 'export CHROME_BIN="/usr/bin/google-chrome-stable"' >> /etc/environment; \
    elif [ -f "/usr/bin/chromium" ]; then \
        echo 'export CHROME_BIN="/usr/bin/chromium"' >> /etc/environment; \
    fi

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile




# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
