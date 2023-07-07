FROM ruby:3.2.2
# make an "app" user
RUN useradd -ms /bin/bash app
# set the working directory
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . ./
USER app
EXPOSE 4444
ENTRYPOINT ["ruby", "--mjit", "./bin/tokenbucketd.rb"]