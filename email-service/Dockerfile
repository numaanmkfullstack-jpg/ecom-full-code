FROM ruby:3.1-alpine

# Install system dependencies
RUN apk add --no-cache build-base wget bash

# Create non-root user
RUN addgroup -g 1001 -S ruby && \
    adduser -S ruby -u 1001 -G ruby

WORKDIR /app

# Install bundler
RUN gem install bundler

# Copy Gemfile first (better caching for dependencies)
COPY Gemfile ./

# Install gems with exact versions from Gemfile and generate a lock file
RUN bundle install

# Copy application code
COPY --chown=ruby:ruby . .

# Switch to non-root user
USER ruby

# Expose port
EXPOSE 3005

# Health check (wget not available in alpine by default, using curl or ruby)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ruby -e "require 'net/http'; Net::HTTP.get_response(URI('http://localhost:3005/health')).code == '200' ? exit(0) : exit(1)" || exit 1

# Run the application
CMD ["ruby", "app.rb"]