FROM alpine:latest

RUN apk --update --no-cache add \
  python3 \
  python3-dev \
  py3-pip \
  py3-wheel \
  bash \
  sudo \
  gcc \
  libc-dev \
  zlib-dev \
  jpeg-dev \
  git

# Create app dir
RUN mkdir /app

# Clone the overviewer repo
RUN git -C /app clone https://github.com/overviewer/Minecraft-Overviewer.git

# Copy libs into repo dir
COPY Imaging.h /app/Minecraft-Overviewer
COPY ImPlatform.h /app/Minecraft-Overviewer
COPY ImagingUtils.h /app/Minecraft-Overviewer

COPY requirements.txt /app/requirements.txt

RUN adduser bukkit --uid 1001 --disabled-password

RUN pip3 install --upgrade --no-cache-dir awscli
RUN pip3 install --upgrade --no-cache-dir -r /app/requirements.txt
RUN mkdir /app/overviewer
RUN python3 /app/Minecraft-Overviewer/setup.py build
RUN python3 /app/Minecraft-Overviewer/setup.py install

COPY render.sh /app
COPY render_modes.py /app
COPY overviewer_config.py /app
RUN ln -s /app/render_modes.py /usr/lib/python3.8/site-packages/
RUN ln -s /app/overviewer_config.py /usr/lib/python3.8/site-packages/
RUN chmod +x /app/render.sh

RUN chown -R bukkit: /app
USER bukkit
WORKDIR /app
RUN overviewer.py --version
