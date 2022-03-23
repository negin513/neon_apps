# This is a direct, FULL build from the centos image; we'll refine this later into centos->base->ESMF->CESM/CTSM->Jupyter(Lab)
FROM rockylinux:8.5

# Let's do all the base stuff, but with a newer version of MPICH due to odd issue with mpi.mod file in old one:
RUN yum -y update && \
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    yum -y install vim emacs-nox git subversion which sudo csh make m4 cmake wget file byacc curl-devel zlib-devel && \
    yum -y install perl-XML-LibXML gcc-gfortran gcc-c++ dnf-plugins-core python3 perl-core && \
    yum -y install ftp xmlstarlet diffutils  && \
    yum -y install libjpeg-devel python36-devel && \
    yum -y install git-lfs latexmk texlive-amscls texlive-anyfontsize texlive-cmap texlive-fancyhdr texlive-fncychap \
                   texlive-dvisvgm texlive-metafont texlive-ec texlive-titlesec texlive-babel-english texlive-tabulary \
                   texlive-framed texlive-wrapfig texlive-parskip texlive-upquote texlive-capt-of texlive-needspace \
                   texlive-times texlive-makeindex texlive-helvetic texlive-courier texlive-gsftopk texlive-dvips texlive-mfware texlive-dvisvgm && \
    pip3 install rst2pdf sphinx sphinxcontrib-programoutput && \
    pip3 install git+https://github.com/esmci/sphinx_rtd_theme.git@version-dropdown-with-fixes && \
    dnf --enablerepo=powertools install -y blas-devel lapack-devel && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf && \
    ldconfig && \
    yum clean all

# Second, let's install MPI - we're doing this by hand because the default packages install into non-standard locations, and
# we want our image as simple as possible.  We're also going to use MPICH, though any of the MPICH ABI-compatible libraries
# will work.  This is for future compatibility with offloading to cloud.

#unsure if ch4:ucx and ch3 are compatible.. need to look.

RUN yum -y install numactl-devel && \
    mkdir /tmp/sources && \
    cd /tmp/sources && \
    wget -q http://www.mpich.org/static/downloads/3.4.1/mpich-3.4.1.tar.gz && \
    tar zxf mpich-3.4.1.tar.gz && \
    cd mpich-3.4.1 && \
    ./configure --prefix=/usr/local --with-device=ch4:ucx && \
    make -j 2 install && \
    rm -rf /tmp/sources && \
    yum clean all
    
    
# Next, let's install HDF5, NetCDF and PNetCDF - we'll do this by hand, since the packaged versions have
# lots of extra dependencies (at least, as of CentOS 7) and this also lets us control their location (eg, put in /usr/local).
# NOTE: We do want to change where we store the versions / download links, so it's easier to change, but that'll happen later.
RUN  mkdir /tmp/sources && \
     cd /tmp/sources && \
     wget -q https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.12/hdf5-1.12.0/src/hdf5-1.12.0.tar.gz && \
     tar zxf hdf5-1.12.0.tar.gz && \
     cd hdf5-1.12.0 && \
     ./configure --prefix=/usr/local && \
     make -j 2 install && \
     cd /tmp/sources && \
     wget -q ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-c-4.7.4.tar.gz  && \
     tar zxf netcdf-c-4.7.4.tar.gz && \
     cd netcdf-c-4.7.4 && \
     ./configure --prefix=/usr/local && \
     make -j 2 install && \
     ldconfig && \
     cd /tmp/sources && \
     wget -q ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-fortran-4.5.3.tar.gz && \
     tar zxf netcdf-fortran-4.5.3.tar.gz && \
     cd netcdf-fortran-4.5.3 && \
     ./configure --prefix=/usr/local && \
     make -j 2 install && \
     ldconfig && \
     cd /tmp/sources && \
     wget -q https://parallel-netcdf.github.io/Release/pnetcdf-1.12.1.tar.gz && \
     tar zxf pnetcdf-1.12.1.tar.gz && \
     cd pnetcdf-1.12.1 && \
     ./configure --prefix=/usr/local && \
     make -j 2 install && \
     ldconfig && \
     rm -rf /tmp/sources

RUN groupadd escomp && \
    useradd -c 'ESCOMP User' -d /home/user -g escomp -m -s /bin/bash user && \
    echo 'export USER=$(whoami)' >> /etc/profile.d/escomp.sh && \
    echo 'export PS1="[\u@escomp \W]\$ "' >> /etc/profile.d/escomp.sh && \
    echo 'user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/escomp

ENV SHELL=/bin/bash \
    LANG=C.UTF-8  \
    LC_ALL=C.UTF-8

USER user
WORKDIR /home/user
CMD ["/bin/bash", "-l"]


# First, let's install ESMF
ENV ESMF_SLUG="ESMF_8_2_0_beta_snapshot_15"
ENV ESMFMKFILE=/usr/local/lib/esmf.mk
RUN mkdir -p /tmp/sources && \
    cd /tmp/sources && \
    #wget -q https://github.com/esmf-org/esmf/archive/${ESMF_SLUG}.tar.gz && \
    wget -q https://github.com/esmf-org/esmf/archive/refs/tags/${ESMF_SLUG}.tar.gz && \
#https://github.com/esmf-org/esmf/archive/refs/tags/ESMF_8_2_0_beta_snapshot_15.tar.gz
    tar zxf ${ESMF_SLUG}.tar.gz && \
    cd esmf-${ESMF_SLUG} && \
    export ESMF_DIR=/tmp/sources/esmf-${ESMF_SLUG} && \
    export ESMF_COMM=mpich3 && \
    export ESMF_BOPT="g" && \
    export ESMF_NETCDF="nc-config" && \
    export ESMF_INSTALL_PREFIX=/usr/local && \
    export ESMF_INSTALL_BINDIR=${ESMF_INSTALL_PREFIX}/bin && \
    export ESMF_INSTALL_DOCDIR=${ESMF_INSTALL_PREFIX}/doc && \
    export ESMF_INSTALL_HEADERDIR=${ESMF_INSTALL_PREFIX}/include && \
    export ESMF_INSTALL_LIBDIR=${ESMF_INSTALL_PREFIX}/lib && \
    export ESMF_INSTALL_MODDIR=${ESMF_INSTALL_PREFIX}/include && \
    export ESMF_TESTEXHAUSTIVE="OFF" && \
    make info && \
    make -j $(nproc) && \
    sudo -E PATH=${PATH}:/usr/local/bin make install && \
    sudo rm -rf /tmp/sources

# Second, let's install CESM - but since we're using NUOPC, and CDEPS seems to need a newer CMake, we're going to remove the
# old version then install the newer one:
COPY Files/ea002e626aee6bc6643e8ab5f998e5e4 /root/.subversion/auth/svn.ssl.server/


RUN sudo yum -y remove cmake && \
    mkdir -p /tmp/sources && \
    wget -q https://github.com/Kitware/CMake/releases/download/v3.20.2/cmake-3.20.2-linux-x86_64.sh && \
    sudo sh cmake-*.sh --prefix=/usr/local --skip-license  && \
    sudo mkdir -p /opt/ncar && \
    cd /opt/ncar && \
    sudo git clone -b ctsm5.1.dev086 https://github.com/ESCOMP/CTSM.git cesm2 && \
    cd cesm2 && \
    sudo ./manage_externals/checkout_externals && \
    sudo chown -R user:escomp /opt/ncar/cesm2 # Bugfix!

# Another bugfix:
COPY Files/esmApp.F90 /opt/ncar/cesm2/cime/src/drivers/nuopc/drivers/cime/esmApp.F90

# Set up the environment - create the group and user, the shell variables, the input data directory and sudo access:
RUN sudo echo 'export CESMDATAROOT=${HOME}' | sudo tee /etc/profile.d/escomp.sh && \
    sudo echo 'export CIME_MACHINE=container' | sudo tee -a /etc/profile.d/escomp.sh && \
    sudo echo 'export USER=$(whoami)' | sudo tee -a /etc/profile.d/escomp.sh && \
    sudo echo 'export PS1="[\u@cesm2.3 \W]\$ "' | sudo tee -a /etc/profile.d/escomp.sh && \
    sudo echo 'ulimit -s unlimited' | sudo tee -a /etc/profile.d/escomp.sh && \
    sudo echo 'export PATH=${PATH}:/opt/ncar/cesm2/cime/scripts' | sudo tee -a /etc/profile.d/escomp.sh && \
    sudo echo 'export PATH=${PATH}:/opt/ncar/cesm2/tools/site_and_regional/' | sudo tee -a /etc/profile.d/escomp.sh


# Add the container versions of the config_machines & config_compilers settings - later, integrate these into CIME
#COPY Files/config_compilers.xml /opt/ncar/cesm2/cime/config/cesm/machines/
#COPY Files/config_machines.xml /opt/ncar/cesm2/cime/config/cesm/machines/
#COPY Files/config_inputdata.xml /opt/ncar/cesm2/cime/config/cesm/
COPY Files/case_setup.py /opt/ncar/cesm2/cime/scripts/lib/CIME/case/case_setup.py

ENV CESMROOT=/opt/ncar/cesm2

CMD ["/bin/bash", "-l"]

# Install software needed for Pangeo
RUN sudo yum install -y graphviz libnsl libspatialite libspatialite-devel xmlstarlet


# Set up the Conda version - using the pangeo/base-image as a foundation here:
ENV CONDA_VERSION=4.8.5-1 \
    CONDA_ENV=default \
    NB_USER=user \
    NB_GROUP=escomp \
    NB_UID=1000 \
    SHELL=/bin/bash \
    CONDA_DIR=/srv/conda

# Additional environment setup that depends on the above:
ENV NB_PYTHON_PREFIX=${CONDA_DIR}/envs/${CONDA_ENV} \
    DASK_ROOT_CONFIG=${CONDA_DIR}/etc \
    HOME=/home/${NB_USER} \
    PATH=${CONDA_DIR}/bin:${PATH}

#RUN sudo yum -y upgrade

# Add the Conda init and set permissions on the directory:
# (Could clean this up, and push changes back to Pangeo -- eg, /srv is hardcoded)
RUN sudo /bin/bash -c "echo '. ${CONDA_DIR}/etc/profile.d/conda.sh ; conda activate ${CONDA_ENV}' > /etc/profile.d/init_conda.sh"  && \
    sudo chown -R ${NB_USER}:${NB_GROUP} /srv

# Install miniforge:
RUN URL="https://github.com/conda-forge/miniforge/releases/download/${CONDA_VERSION}/Miniforge3-${CONDA_VERSION}-Linux-x86_64.sh" && \
    wget --quiet ${URL} -O miniconda.sh && \
    /bin/bash miniconda.sh -u -b -p ${CONDA_DIR} && \
    rm miniconda.sh && \
    conda clean -afy && \
    find ${CONDA_DIR} -follow -type f -name '*.a' -delete && \
    find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete

COPY --chown=${NB_USER}:${NB_GROUP} Files/*yml /srv/

RUN mv /srv/condarc.yml ${CONDA_DIR}/.condarc && \
    mv /srv/dask_config.yml ${CONDA_DIR}/etc/dask.yml
    
    
RUN conda env create --name ${CONDA_ENV} -f /srv/environment.yml  && \
        conda clean -yaf && \
        find ${CONDA_DIR} -follow -type f -name '*.a' -delete && \
        find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete && \
        find ${CONDA_DIR} -follow -type f -name '*.js.map' -delete && \
        find ${NB_PYTHON_PREFIX}/lib/python*/site-packages/bokeh/server/static -follow -type f -name '*.js' ! -name '*.min.js' -delete

RUN export PATH=${NB_PYTHON_PREFIX}/bin:${PATH} && \
    jupyter labextension install --clean \
         @jupyter-widgets/jupyterlab-manager \
         @jupyterlab/geojson-extension \
         dask-labextension \
         @pyviz/jupyterlab_pyviz \
         jupyter-leaflet && \
    sudo rm -rf /tmp/* && \
    rm -rf ${HOME}/.cache ${HOME}/.npm ${HOME}/.yarn && \
    rm -rf ${NB_PYTHON_PREFIX}/share/jupyter/lab/staging && \
    find ${CONDA_DIR} -follow -type f -name '*.a' -delete && \
    find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete && \
    find ${CONDA_DIR} -follow -type f -name '*.js.map' -delete


COPY Files/start /srv
RUN sudo chmod +x /srv/start

COPY Files/cesm_aliases.ipy /etc/ipython/
RUN  sudo /bin/bash -c 'echo "c.InteractiveShellApp.exec_files = [ \"/etc/ipython/cesm_aliases.ipy\" ] " >> /etc/ipython/ipython_config.py'

#ADD https://api.github.com/repos/NCAR/CESM-Lab-Tutorial/git/refs/heads/master version.json
##RUN git clone https://github.com/NCAR/CESM-Lab-Tutorial.git /srv/tutorials
#COPY Files/NEON-visualization/*ipynb /srv/tutorials/
COPY Files/cartopy/shapefiles /srv/conda/envs/default/lib/python3.7/site-packages/cartopy/data/shapefiles/
COPY Files/cesm.py /srv/conda/envs/default/lib/python3.7/site-packages/
COPY Files/neon_site.py /srv/conda/envs/default/lib/python3.7/site-packages/
#COPY Files/NEON-visualization/neon_utils.py /srv/conda/envs/default/lib/python3.7/site-packages/
RUN mkdir -p /srv/tutorials && \
    curl -s https://raw.githubusercontent.com/NCAR/NEON-visualization/main/notebooks/NEON_Visualization_Tutorial.ipynb -o /srv/tutorials/NEON_Visualization_Tutorial.ipynb && \
    curl -s https://raw.githubusercontent.com/NCAR/NEON-visualization/main/notebooks/NEON_Simulation_Tutorial.ipynb -o /srv/tutorials/NEON_Simulation_Tutorial.ipynb && \
    chmod ugo+r /srv/tutorials/* && \
    curl -s https://raw.githubusercontent.com/NCAR/NEON-visualization/main/notebooks/neon_utils.py -o /srv/conda/envs/default/lib/python3.7/site-packages/neon_utils.py && \
    chmod ugo+rx /srv/conda/envs/default/lib/python3.7/site-packages/neon_utils.py


EXPOSE 8888
USER user
WORKDIR /home/user
ENV SHELL /bin/bash
ENTRYPOINT ["/srv/start"]
