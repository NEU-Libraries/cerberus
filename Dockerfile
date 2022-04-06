FROM ruby:3.0
# update the repository sources list
# and install dependencies
RUN apt-get update \
    && apt-get install -y nodejs \
    && apt-get -y autoclean

RUN curl -L https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64 > /usr/local/bin/cc-test-reporter
RUN chmod +x /usr/local/bin/cc-test-reporter

RUN useradd -ms /bin/bash cerberus
USER cerberus

COPY Gemfile* /tmp/
WORKDIR /tmp
RUN bundle install -j8

RUN mkdir -p /home/cerberus/web
WORKDIR /home/cerberus/web

COPY --chown=cerberus:cerberus . /home/cerberus/web
