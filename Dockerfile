FROM ruby:3.0
# update the repository sources list
# and install dependencies
RUN apt-get update \
    && apt-get install -y nodejs \
    && apt-get -y autoclean

RUN useradd -ms /bin/bash cerberus
USER cerberus

RUN mkdir -p /home/cerberus/web
WORKDIR /home/cerberus/web

COPY --chown=cerberus:cerberus . /home/cerberus/web
RUN bundle update --bundler
RUN bundle install
