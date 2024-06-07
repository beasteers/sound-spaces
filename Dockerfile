# Base image
FROM nvidia/cudagl:10.1-devel-ubuntu16.04

# Setup basic packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    vim \
    ca-certificates \
    libjpeg-dev \
    libpng-dev \
    libglfw3-dev \
    libglm-dev \
    libx11-dev \
    libomp-dev \
    libegl1-mesa-dev \
    libsndfile1 \
    pkg-config \
    wget \
    zip \
    unzip &&\
    rm -rf /var/lib/apt/lists/*

# Install conda
RUN curl -vk -sL "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" > ~/"miniconda.sh" &&\
    chmod +x ~/miniconda.sh &&\
    ~/miniconda.sh -b -p /opt/conda &&\
    rm ~/miniconda.sh &&\
    /opt/conda/bin/conda install numpy pyyaml scipy ipython mkl mkl-include &&\
    /opt/conda/bin/conda clean -ya
ENV PATH /opt/conda/bin:$PATH

# Install cmake
RUN wget https://github.com/Kitware/CMake/releases/download/v3.14.0/cmake-3.14.0-Linux-x86_64.sh
RUN mkdir /opt/cmake
RUN sh /cmake-3.14.0-Linux-x86_64.sh --prefix=/opt/cmake --skip-license
RUN ln -s /opt/cmake/bin/cmake /usr/local/bin/cmake
RUN cmake --version

# Conda environment
RUN conda create -n soundspaces python=3.9 cmake=3.14.0

# Setup habitat-sim
RUN git clone --branch stable https://github.com/facebookresearch/habitat-sim.git
RUN /bin/bash -c ". activate soundspaces; cd habitat-sim; pip install -r requirements.txt; python setup.py install --headless --audio"

# Install challenge specific habitat-lab
RUN git clone --branch stable https://github.com/facebookresearch/habitat-lab.git
RUN /bin/bash -c ". activate soundspaces; cd habitat-lab; git checkout v0.1.6; pip install -e ."

RUN apt-get update && apt-get install -y bison gawk && rm -rf /var/lib/apt/lists/*

# install GLIBC
RUN git clone git://sourceware.org/git/glibc.git && cd glibc && git checkout glibc-2.29 && mkdir build && cd build && ../configure --prefix "$(pwd)/install" && make -j `nproc` && make install -j `nproc` && mkdir $HOME/bin && cp $(pwd)/install/lib/libm.so.6 $HOME/bin/ && echo 'export LD_LIBRARY_PATH=$HOME/bin:$LD_LIBRARY_PATH' >> ~/.bashrc

# Install soundspaces
WORKDIR /sound-spaces
COPY setup.py ./
COPY soundspaces soundspaces/
COPY ss_baselines ss_baselines/
RUN pip install -e .
COPY . .

RUN conda init
RUN echo 'conda activate soundspaces' >> ~/.bashrc

# Silence habitat-sim logs
ENV GLOG_minloglevel=2
ENV MAGNUM_LOG="quiet"
