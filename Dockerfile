FROM ruby:3.0
# Interactive for nvm and node
SHELL ["/bin/bash", "--login", "-i", "-c"]
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.2/install.sh | bash
RUN source /root/.bashrc && nvm install node

SHELL ["/bin/bash", "--login", "-c"]
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
# update the repository sources list
# and install dependencies
RUN apt-get update \
    && apt-get install -y curl yarn\
    && apt-get -y autoclean

RUN useradd -ms /bin/bash cerberus
USER cerberus

RUN mkdir -p /home/cerberus/web
WORKDIR /home/cerberus/web

COPY --chown=cerberus:cerberus . /home/cerberus/web
RUN bundle update --bundler
RUN bundle install
# RUN yarn install
