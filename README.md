[![Maintainability](https://api.codeclimate.com/v1/badges/319fb72eb18232337a83/maintainability)](https://codeclimate.com/github/NEU-Libraries/cerberus/maintainability) [![Test Coverage](https://api.codeclimate.com/v1/badges/319fb72eb18232337a83/test_coverage)](https://codeclimate.com/github/NEU-Libraries/cerberus/test_coverage) [![Build and Test](https://github.com/NEU-Libraries/cerberus/actions/workflows/build_test.yml/badge.svg)](https://github.com/NEU-Libraries/cerberus/actions/workflows/build_test.yml)

# Cerberus

Cerberus is the Ruby on Rails codebase for Northeastern's Digital Repository Service.

The code base utilizes Valkyrie, Blacklight, Solr and PostgreSQL

## Getting started

Make sure you have docker installed.

Get a copy of the codebase
```
git clone git@github.com:NEU-Libraries/cerberus.git
```

Use docker compose to pull down the containers and build Cerberus
```
ATLAS=0.0.157 docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
```

Once running, use another console/tab to go inside the container.
```
docker exec -ti cerberus-web-1 /bin/sh
```

Once inside, generate some test objects
```
bundle exec rake reset:data
```