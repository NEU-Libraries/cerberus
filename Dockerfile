FROM ruby:3.2.2-slim
# One apt layer: a later RUN can't reclaim space cleaned from an earlier one
# (the union FS keeps the earlier layer's files), so the package lists are
# purged in the same RUN that populates them. LibreOffice powers Word/PowerPoint
# → PDF renditions (PdfRenditionJob via libreconv); --no-install-recommends keeps
# its GUI/Java stack out, and fonts-liberation supplies metric-compatible
# Times/Arial/Courier substitutes so converted documents don't reflow.
RUN apt-get update \
    && apt-get install -y curl git build-essential libpq-dev libmagic-dev libvips-dev libyaml-dev libimage-exiftool-perl ffmpeg \
    && apt-get install -y --no-install-recommends libreoffice-writer libreoffice-impress fonts-liberation \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash cerberus
USER cerberus

RUN mkdir -p /home/cerberus/storage /home/cerberus/images /home/cerberus/uploads

COPY --chown=cerberus:cerberus Gemfile* /tmp/
WORKDIR /tmp
RUN git config --global url."https://github.com/".insteadOf 'git@github.com:'
RUN bundle install -j8

RUN mkdir -p /home/cerberus/web
WORKDIR /home/cerberus/web

RUN echo "IRB.conf[:USE_AUTOCOMPLETE] = false" > /home/cerberus/.irbrc

COPY --chown=cerberus:cerberus . /home/cerberus/web
RUN git config --global --add safe.directory /home/cerberus/web
