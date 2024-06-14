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

RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && apt-get install -y git-lfs && rm -rf /var/lib/apt/lists/*

# Conda environment
RUN conda create -n soundspaces python=3.9 cmake=3.14.0
RUN /bin/bash -c ". activate soundspaces; conda install -y conda-forge::gcc_linux-64"

# Setup habitat-sim
RUN git clone --branch stable https://github.com/facebookresearch/habitat-sim.git
RUN /bin/bash -c ". activate soundspaces; cd habitat-sim; git checkout RLRAudioPropagationUpdate; pip install -r requirements.txt; python setup.py install --headless --audio"

# Install challenge specific habitat-lab v0.1.6
RUN git clone --branch stable https://github.com/facebookresearch/habitat-lab.git
RUN /bin/bash -c ". activate soundspaces; cd habitat-lab; git checkout v0.2.2; pip install -e ."

RUN apt-get update && apt-get install -y bison gawk && rm -rf /var/lib/apt/lists/*

# install GLIBC
RUN git clone git://sourceware.org/git/glibc.git && cd glibc && git checkout glibc-2.29 && mkdir build && cd build && ../configure --prefix "$(pwd)/install" && make -j `nproc` && make install -j `nproc` && mkdir $HOME/bin && cp $(pwd)/install/lib/libm.so.6 $HOME/bin/ && echo 'export LD_LIBRARY_PATH=$HOME/bin:$LD_LIBRARY_PATH' >> ~/.bashrc

# Install soundspaces
WORKDIR /sound-spaces
COPY setup.py ./
COPY soundspaces soundspaces/
COPY ss_baselines ss_baselines/
RUN pip install -e .
RUN pip install trimesh

# make sure conda activates by default
RUN conda init
RUN echo 'conda activate soundspaces' >> ~/.bashrc
RUN /bin/bash -c ". activate soundspaces; conda install -y -c conda-forge nb_conda_kernels ipykernel"
RUN /bin/bash -c ". activate soundspaces; python -m ipykernel install --user --name=soundspaces"
RUN /bin/bash -c ". activate soundspaces; pip install jupyterlab"
RUN /bin/bash -c ". activate soundspaces; pip install librosa[display] pyroomacoustics"

RUN echo '#!/bin/bash -i\nexec "$@"' > /entrypoint.sh && chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# copy the rest of the repo
COPY . .

# Silence habitat-sim logs
ENV GLOG_minloglevel=2
ENV MAGNUM_LOG="quiet"
ENV SHELL=/bin/bash
#ENV DISPLAY=:0
ENV DISPLAY=host.docker.internal:0.0
