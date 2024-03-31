# SeleniumBase Docker Image
FROM ubuntu:18.04

WORKDIR /cita-checker/SeleniumBase

#=======================================
# Install Python and Basic Python Tools
#=======================================
RUN apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false update
RUN apt-get install -y python3 python3-pip python3-setuptools python3-dev python-distribute
RUN alias python=python3
RUN echo "alias python=python3" >> ~/.bashrc

#=================================
# Install Bash Command Line Tools
#=================================
RUN apt-get -qy --no-install-recommends install \
    sudo \
    unzip \
    wget \
    curl \
    libxi6 \
    libgconf-2-4 \
    vim \
    xvfb \
  && rm -rf /var/lib/apt/lists/*

#===========================================
# Install VNC Server, Window Manager, NoVNC
#===========================================
ENV DISPLAY=:99.0
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    python-numpy \
    net-tools \
    x11vnc \
    xfce4 \
    xfce4-goodies \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /.novnc && cd /.novnc \
    && wget -qO- https://github.com/novnc/noVNC/archive/v1.0.0.tar.gz | tar xz --strip 1 -C $PWD \
    && mkdir /.novnc/utils/websockify \
    && wget -qO- https://github.com/novnc/websockify/archive/v0.6.1.tar.gz | tar xz --strip 1 -C /.novnc/utils/websockify \
    && ln -s /.novnc/vnc.html /.novnc/index.html

EXPOSE 5900
EXPOSE 6080

#================
# Install Chrome
#================
RUN curl -sS -o - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list && \
    apt-get -yqq update && \
    apt-get -yqq install google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

#=================
# Install Firefox
#=================
RUN apt-get -qy --no-install-recommends install \
     $(apt-cache depends firefox | grep Depends | sed "s/.*ends:\ //" | tr '\n' ' ') \
  && rm -rf /var/lib/apt/lists/* \
  && cd /tmp \
  && wget --no-check-certificate -O firefox-esr.tar.bz2 \
    'https://download.mozilla.org/?product=firefox-esr-latest&os=linux64&lang=en-US' \
  && tar -xjf firefox-esr.tar.bz2 -C /opt/ \
  && ln -s /opt/firefox/firefox /usr/bin/firefox \
  && rm -f /tmp/firefox-esr.tar.bz2

#===============
# Install Brave
#===============
RUN apt-get update && \
    apt-get install -y curl software-properties-common apt-transport-https gnupg
RUN curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
    tee /etc/apt/sources.list.d/brave-browser-release.list
RUN apt-get update
RUN apt-get install -y brave-browser

#=======================
# Update Python Version
#=======================
RUN apt-get update -y
RUN apt-get -qy --no-install-recommends install python3.8
RUN rm /usr/bin/python3
RUN ln -s python3.8 /usr/bin/python3

#=============================================
# Allow Special Characters in Python Programs
#=============================================
RUN export PYTHONIOENCODING=utf8
RUN echo "export PYTHONIOENCODING=utf8" >> ~/.bashrc

#=====================
# Set up SeleniumBase
#=====================
COPY SeleniumBase/sbase/ ./sbase/
COPY SeleniumBase/seleniumbase/ ./seleniumbase/
COPY SeleniumBase/examples/ ./examples/
COPY SeleniumBase/integrations/ ./integrations/
COPY SeleniumBase/requirements.txt ./
COPY SeleniumBase/setup.py ./
RUN find . -name '*.pyc' -delete
RUN find . -name __pycache__ -delete
RUN pip3 install --upgrade pip setuptools wheel
RUN cd /cita-checker/SeleniumBase && ls && pip3 install -r requirements.txt --upgrade
RUN cd /cita-checker/SeleniumBase && pip3 install .

#=====================
# Download WebDrivers
#=====================
RUN wget https://github.com/mozilla/geckodriver/releases/download/v0.34.0/geckodriver-v0.34.0-linux64.tar.gz
RUN tar -xvzf geckodriver-v0.34.0-linux64.tar.gz
RUN chmod +x geckodriver
RUN mv geckodriver /usr/local/bin/
RUN wget https://chromedriver.storage.googleapis.com/72.0.3626.69/chromedriver_linux64.zip
RUN unzip chromedriver_linux64.zip
RUN chmod +x chromedriver
RUN mv chromedriver /usr/local/bin/

#==========================================
# Create entrypoint and grab example tests
#==========================================
COPY ../docker-entrypoint.sh /docker-entrypoint.sh
COPY SeleniumBase/integrations/docker/docker_config.cfg ./examples/
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/bash"]
