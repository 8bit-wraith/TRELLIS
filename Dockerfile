# Use NVIDIA CUDA base image with Python
FROM nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04 AS builder

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1a
ENV CUDA_HOME=/usr/local/cuda-12.9.1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.12 \
    python3.12-dev \
    git \
    wget \
    build-essential \
    libglfw3-dev \
    libgles2-mesa-dev \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.12 as default and install pip
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3.12 get-pip.py && \
    rm get-pip.py

# Create app directory
WORKDIR /app

# Copy the entire project
COPY . .

# Install PyTorch with CUDA 11.8 support
RUN python3.12 -m pip install --no-cache-dir torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cu118

# Install other Python dependencies
RUN python3.12 -m pip install --no-cache-dir \
    numpy \
    scipy \
    scikit-image \
    gradio \
    gradio-litmodel3d \
    imageio \
    imageio-ffmpeg \
    easydict \
    pillow \
    trimesh \
    pymeshlab \
    rembg[gpu] \
    huggingface-hub \
    safetensors \
    einops \
    transformers \
    accelerate \
    diffusers \
    omegaconf \
    networkx \
    xformers==0.0.27.post2

# Build and install custom extensions
ENV TORCH_CUDA_ARCH_LIST="6.0;6.1;7.0;7.5;8.0;8.6;8.9;9.0"
ENV MAX_JOBS=4

# Install submodules with error handling
RUN cd /app && \
    git submodule update --init --recursive || true

# Build extensions that don't require complex setup
RUN python3.12 -m pip install -e ./extensions/vox2seq || true

# Production stage
FROM nvidia/cuda:12.9.1-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda-12.9.1
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics
ENV SPCONV_ALGO=native
ENV ATTN_BACKEND=xformers

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    python3.12 \
    libglfw3 \
    libgles2 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgomp1 \
    ffmpeg \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.12 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1

# Create non-root user
RUN useradd -m -s /bin/bash appuser

# Copy from builder
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /app /app

# Create necessary directories
RUN mkdir -p /app/tmp /app/outputs /app/models && \
    chown -R appuser:appuser /app

# Download models at build time (optional - comment out if you want to download at runtime)
# RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('microsoft/TRELLIS-image-large', cache_dir='/app/models')"

USER appuser
WORKDIR /app

# Expose Gradio default port
EXPOSE 7860

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:7860/health')" || exit 1

# Start the application
CMD ["python", "app.py"] 