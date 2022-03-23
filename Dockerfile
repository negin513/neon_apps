FROM rockylinux:8.5
  
RUN yum -y update && \
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    yum -y install vim emacs-nox git subversion which sudo csh make m4 cmake wget file byacc curl-devel zlib-devel && \
    yum -y install perl-XML-LibXML gcc-gfortran gcc-c++ dnf-plugins-core python3 perl-core && \
    yum -y install ftp xmlstarlet diffutils  && \
    yum clean all


RUN yum -y install git-lfs latexmk texlive-amscls texlive-anyfontsize texlive-cmap texlive-fancyhdr texlive-fncychap \
                   texlive-dvisvgm texlive-metafont texlive-ec texlive-titlesec texlive-babel-english texlive-tabulary \
                   texlive-framed texlive-wrapfig texlive-parskip texlive-upquote texlive-capt-of texlive-needspace \
                   texlive-times texlive-makeindex texlive-helvetic texlive-courier texlive-gsftopk texlive-dvips texlive-mfware texlive-dvisvgm && \
    yum clean all

RUN yum -y install libjpeg-devel python36-devel  && \
    yum clean all

RUN pip3 install rst2pdf sphinx sphinxcontrib-programoutput && \
    pip3 install git+https://github.com/esmci/sphinx_rtd_theme.git@version-dropdown-with-fixes && \
    dnf --enablerepo=powertools install -y blas-devel lapack-devel && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf && \
    ldconfig && \
    yum clean all
