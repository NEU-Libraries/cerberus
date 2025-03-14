FROM ruby:3.2-slim
# update the repository sources list
# and install dependencies
RUN apt-get update \
    && apt-get install -y nodejs curl git build-essential libpq-dev libmagic-dev libvips-dev libyaml-dev \
    && apt-get -y autoclean

RUN curl -L https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64 > /usr/local/bin/cc-test-reporter
RUN chmod +x /usr/local/bin/cc-test-reporter

RUN useradd -ms /bin/bash cerberus
USER cerberus

RUN mkdir -p /home/cerberus/storage
RUN mkdir -p /home/cerberus/images

COPY --chown=cerberus:cerberus Gemfile* /tmp/
WORKDIR /tmp
RUN git config --global url."https://github.com/".insteadOf 'git@github.com:'
RUN bundle install -j8

RUN mkdir -p /home/cerberus/web
WORKDIR /home/cerberus/web

RUN echo "IRB.conf[:USE_AUTOCOMPLETE] = false" > /home/cerberus/.irbrc

COPY --chown=cerberus:cerberus . /home/cerberus/web
RUN git config --global --add safe.directory /home/cerberus/web
