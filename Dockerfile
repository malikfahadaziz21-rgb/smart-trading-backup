# Use Ubuntu as the base
FROM ubuntu:22.04

# Install Wine (to run Windows apps) and Xvfb (to pretend there is a monitor)
RUN apt-get update && apt-get install -y \
    wine64 \
    xvfb \
    && apt-get clean

# Set the working directory inside the container
WORKDIR /compiler

# Copy your MT5 folder and scripts into the container
COPY ./MT5 /compiler/MT5
COPY ./scripts /compiler/scripts
COPY compile.sh /compiler/compile.sh

# Give permission to run the script
RUN chmod +x /compiler/compile.sh

# Run the compilation script
ENTRYPOINT ["/bin/bash", "/compiler/compile.sh"]