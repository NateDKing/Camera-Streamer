FROM balenalib/jetson-nano-ubuntu:bionic as buildstep

WORKDIR /usr/src/app

# Don't prompt with any configuration questions
ENV DEBIAN_FRONTEND noninteractive

# Install CUDA, CUDA compiler and some utilities
RUN \
    apt-get update && apt-get install -y cuda-toolkit-10-2 cuda-compiler-10-2 \
    lbzip2 xorg-dev \
    cmake wget unzip \
    libgtk2.0-dev \
    libavcodec-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libdc1394-22-dev -y --no-install-recommends && \
    echo "/usr/lib/aarch64-linux-gnu/tegra" > /etc/ld.so.conf.d/nvidia-tegra.conf && \
    ldconfig
    # wget https://github.com/opencv/opencv/archive/4.0.1.zip && \
    # unzip 4.0.1.zip && \
    # wget https://github.com/opencv/opencv_contrib/archive/4.0.1.zip -O opencv_modules.4.0.1.zip && \
    # unzip opencv_modules.4.0.1.zip && rm opencv_modules.4.0.1.zip && \

RUN \    
    wget https://github.com/opencv/opencv/archive/4.0.1.zip && \
    unzip 4.0.1.zip && \
    wget https://github.com/opencv/opencv_contrib/archive/4.0.1.zip -O opencv_modules.4.0.1.zip && \
    unzip opencv_modules.4.0.1.zip

RUN \
    export CUDA_HOME=/usr/local/cuda-10.2/ && \
    export LD_LIBRARY_PATH=${CUDA_HOME}/lib64 && \
    PATH=${CUDA_HOME}/bin:${PATH} && export PATH && \
    mkdir -p opencv-4.0.1/build && cd opencv-4.0.1/build && \
    cmake \
	-D WITH_CUDA=ON \
	-D CUDA_ARCH_BIN=5.3,6.2,7.2 \
	-D CUDA_ARCH_PTX= \
	-D WITH_GSTREAMER=ON \
	-D WITH_LIBV4L=ON \
	-D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib-4.0.1/modules \
	-D CMAKE_BUILD_TYPE=RELEASE \
	-D CMAKE_INSTALL_PREFIX=$(python3 -c "import sys; print(sys.prefix)") \
	-D PYTHON_EXECUTABLE=$(which python3) \
	-D BUILD_EXAMPLES=OFF \
        -D BUILD_opencv_python2=ON \
        -D BUILD_opencv_python3=ON \
        -D CUDA_FAST_MATH=ON \
        -D CUDNN_VERSION='8.0' \
        -D EIGEN_INCLUDE_PATH=/usr/include/eigen3 \
        -D ENABLE_NEON=ON \
        -D OPENCV_DNN_CUDA=ON \
        -D OPENCV_ENABLE_NONFREE=ON \        
        -D OPENCV_GENERATE_PKGCONFIG=ON \
        -D WITH_CUBLAS=ON \        
        -D WITH_CUDNN=ON \
        -D WITH_OPENGL=ON .. && \
    make -j2 && make install && ldconfig

FROM balenalib/jetson-nano-ubuntu:bionic as final

# Starting with a fresh new base image, but with access to files in previous build

# Uncomment if planning to use libs from here
#COPY --from=buildstep /usr/local/cuda-10.2 /usr/local/cuda-10.2

# Minimum CUDA runtime libraries
COPY --from=buildstep /usr/lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu

# OpenCV runtime libraries
COPY --from=buildstep /usr/local/lib /usr/local/lib

# Demo apps
COPY --from=buildstep /usr/src/app/ /usr/src/app/

ENV DEBIAN_FRONTEND noninteractive

# Download and install BSP binaries for L4T 32.4.4
RUN apt-get update && apt-get install -y wget tar lbzip2 python3 libegl1 && \
    wget https://developer.nvidia.com/embedded/L4T/r32_Release_v4.4/r32_Release_v4.4-GMC3/T210/Tegra210_Linux_R32.4.4_aarch64.tbz2 && \       
    tar xf Tegra210_Linux_R32.4.4_aarch64.tbz2 && \
    cd Linux_for_Tegra && \
    sed -i 's/config.tbz2\"/config.tbz2\" --exclude=etc\/hosts --exclude=etc\/hostname/g' apply_binaries.sh && \
    sed -i 's/install --owner=root --group=root \"${QEMU_BIN}\" \"${L4T_ROOTFS_DIR}\/usr\/bin\/\"/#install --owner=root --group=root \"${QEMU_BIN}\" \"${L4T_ROOTFS_DIR}\/usr\/bin\/\"/g' nv_tegra/nv-apply-debs.sh && \
    sed -i 's/LC_ALL=C chroot . mount -t proc none \/proc/ /g' nv_tegra/nv-apply-debs.sh && \
    sed -i 's/umount ${L4T_ROOTFS_DIR}\/proc/ /g' nv_tegra/nv-apply-debs.sh && \
    sed -i 's/chroot . \//  /g' nv_tegra/nv-apply-debs.sh && \
    ./apply_binaries.sh -r / --target-overlay && cd .. \
    rm -rf Tegra210_Linux_R32.4.4_aarch64.tbz2 && \
    rm -rf Linux_for_Tegra && \
    echo "/usr/lib/aarch64-linux-gnu/tegra" > /etc/ld.so.conf.d/nvidia-tegra.conf && ldconfig

RUN apt-get update && apt-get install -y lbzip2 xorg

ENV UDEV=1

ENV LD_LIBRARY_PATH=/usr/local/lib

# Enable systemd init system
ENV INITSYSTEM on

# Set our working directory
WORKDIR /usr/src/app

# Install pip
RUN apt-get update && \
    apt-get install -yq \
    python3 \
    python3-dev \
    python3-pip 
RUN pip3 install --upgrade pip

# Copy requirements.txt first for better cache on later pushes
COPY requirements.txt requirements.txt

# pip install python deps from requirements.txt on the resin.io build server
RUN pip install -r requirements.txt

RUN pip list

# This will copy all files in our root to the working  directory in the container
COPY . ./

# Enable udevd so that plugged dynamic hardware devices show up in our container.
ENV UDEV=1

# main.py will run when container starts up on the device
CMD ["python3","-u","src/main.py"]