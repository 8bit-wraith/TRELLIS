# Deploying TRELLIS on Coolify

This guide helps you deploy the TRELLIS 3D generation application on Coolify with GPU support.

## Prerequisites

- Coolify instance with GPU support enabled
- NVIDIA GPU with at least 16GB VRAM (24GB+ recommended)
- NVIDIA drivers and nvidia-docker2 installed on the host
- Sufficient disk space for models (~50GB)

## Quick Start

1. **Fork or clone this repository** to your Git provider

2. **In Coolify**, create a new Docker Compose service

3. **Configure the service:**
   - Set the Git repository URL
   - Set branch to `main` (or your preferred branch)
   - Enable "Build on Server" if you want to build the image on Coolify

4. **Environment Variables** - Add these in Coolify:
   ```
   PORT=7860
   CUDA_VISIBLE_DEVICES=0
   NVIDIA_VISIBLE_DEVICES=all
   NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics
   ```

5. **GPU Configuration** - Ensure your Coolify server has:
   ```bash
   # Check NVIDIA driver
   nvidia-smi
   
   # Verify nvidia-docker2
   docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu20.04 nvidia-smi
   ```

6. **Deploy** the application

## Configuration Options

### GPU Memory Settings

Adjust in `docker-compose.yml` based on your GPU:

- **A100 40GB**: 24G limit, 16G reservation
- **RTX 3090/4090 24GB**: 20G limit, 16G reservation
- **RTX 3080 16GB**: 14G limit, 12G reservation

### Model Caching

Models are downloaded on first run and cached in the `trellis_models` volume. This prevents re-downloading on container restarts.

### Performance Tuning

For optimal performance:

1. Use `SPCONV_ALGO=native` to avoid startup benchmarking
2. Use `ATTN_BACKEND=xformers` for memory efficiency
3. Increase shared memory: `shm_size: '8gb'` in docker-compose.yml

## Troubleshooting

### Out of Memory Errors

1. Reduce memory limits in docker-compose.yml
2. Ensure no other GPU processes are running
3. Try using a smaller model variant

### Model Download Issues

1. Check disk space in the models volume
2. Verify internet connectivity
3. Consider pre-downloading models during build (see Dockerfile)

### GPU Not Detected

1. Verify NVIDIA drivers: `nvidia-smi`
2. Check Docker GPU support: `docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu20.04 nvidia-smi`
3. Ensure `runtime: nvidia` is set in docker-compose.yml

## Advanced Configuration

### Using Multiple GPUs

Change in docker-compose.yml:
```yaml
devices:
  - driver: nvidia
    count: all  # Use all available GPUs
    capabilities: [gpu]
```

### Custom Model Path

Mount a local model directory:
```yaml
volumes:
  - /path/to/local/models:/app/models
```

### SSL/HTTPS

Configure in Coolify's service settings or add a reverse proxy.

## Resource Requirements

- **Minimum**: 16GB GPU VRAM, 32GB RAM, 100GB disk
- **Recommended**: 24GB+ GPU VRAM, 64GB RAM, 200GB disk
- **Network**: Good bandwidth for model downloads (~10GB)

## Security Considerations

1. The application runs as non-root user `appuser`
2. Set `no-new-privileges` security option
3. Consider adding authentication if exposing publicly
4. Use environment variables for sensitive data

## Monitoring

- Health checks run every 30s
- Logs are limited to 3 files of 10MB each
- Monitor GPU usage with `nvidia-smi` on the host

## Updates

To update the application:

1. Pull the latest code changes
2. Rebuild in Coolify
3. Models and data in volumes persist across updates 