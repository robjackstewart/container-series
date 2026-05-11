FROM ruby:3.3-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 4567
ENV RACK_ENV=production PORT=4567

RUN adduser --disabled-password --gecos '' appuser && chown -R appuser /app
USER appuser

CMD ["bundle", "exec", "ruby", "app.rb"]
