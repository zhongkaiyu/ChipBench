# Use Ubuntu 22.04 as base image
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PATH="/usr/local/bin:$PATH"

# Install basic tools and dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    autoconf \
    flex \
    bison \
    gperf \
    curl \
    wget \
    pkg-config \
    verilator \
    libsystemc-dev \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# Install ICARUS Verilog v12
RUN git clone https://github.com/steveicarus/iverilog.git /tmp/iverilog && \
    cd /tmp/iverilog && \
    git checkout v12-branch && \
    sh ./autoconf.sh && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/iverilog

# Install Python packages
RUN python3 -m pip install --upgrade pip
COPY requirements.txt .
RUN pip install -r requirements.txt

RUN ln -s /usr/bin/python3 /usr/bin/python
RUN ln -sf /bin/bash /bin/sh

# Set working directory
WORKDIR /workspace/verilogeval

# Expose a terminal
CMD ["/bin/bash"]