FROM amazonlinux
RUN yum -y install awscli
RUN yum -y install libicu
RUN yum -y install wget tar gzip
RUN yum -y update ca-certificates
RUN mkdir /app
WORKDIR /app
RUN bash -c 'wget "https://unmined.net/download/unmined-cli-linux-x64-dev/?tmstv=$(date "+%s")" -O - | tar -xz'
RUN mv unmined-cli*x64/ unmined-cli/
RUN mkdir map_src
RUN mkdir map_web
ADD render.sh render.sh
ADD main.index.html main.index.html
RUN chmod +x render.sh
CMD /app/render.sh
