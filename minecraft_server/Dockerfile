FROM openjdk:17-alpine

RUN apk --update --no-cache add \
  python3 \
  py3-pip \
  bash \
  sudo

RUN pip3 install --upgrade --no-cache-dir awscli

RUN mkdir /app
RUN mkdir /app/data
RUN adduser bukkit --uid 1001 --disabled-password
RUN chown -R bukkit: /app

COPY start.sh /app
COPY rcon.py /app
COPY mcrcon.py /app
COPY backup.sh /app
RUN ln -s /app/backup.sh /etc/periodic/15min/backup

RUN chmod +x /app/start.sh
RUN chmod +x /app/backup.sh

CMD /app/start.sh
