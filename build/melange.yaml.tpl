package:
  name: fastapi-app
  # Defines the package name - changed to a generic FastAPI application identifier

  version: 0.0.0
  # Specifies the version number of this package release
  annotations:
    git_commit: "__GIT_HASH__"
    git_dirty: "__DIRTY__"

  epoch: 0
  # Epoch is used for package versioning conflicts - 0 means no special versioning override

  description: "Generic FastAPI application"
  # Human-readable description - now describes a generic FastAPI app

  copyright:
    - license: MIT
    # Declares this package is released under the MIT open-source license

environment:
  # Defines the build environment configuration

  contents:
    # Specifies what repositories and packages are available during build

    repositories:
      - https://packages.wolfi.dev/os
      # Adds the Wolfi OS package repository as a source for dependencies

    keyring:
      - https://packages.wolfi.dev/os/wolfi-signing.rsa.pub
      # Specifies the public key used to verify package signatures from the repository

    packages:
      # Lists all system packages needed for the build process

      - python-3.12
      # Installs Python version 3.12

      - wolfi-base
      # Installs base Wolfi system utilities

      - ca-certificates-bundle
      # Installs SSL/TLS certificates for secure HTTPS connections

      - busybox
      # Installs BusyBox - a lightweight collection of Unix utilities

      - curl
      # Installs curl utility, needed to download the uv package manager

pipeline:
  # Defines the series of build steps that will be executed in order

  - name: "Setup build environment"
    # First pipeline stage - sets up the directory structure

    runs: |
      # Create application directory structure IN THE PACKAGE
      mkdir -p "${{targets.destdir}}/app"
      # Creates /app directory in the target destination (where package files go)
      # The ${{targets.destdir}} variable points to the package staging area

      mkdir -p "${{targets.destdir}}/usr/local/bin"
      # Creates /usr/local/bin directory for executable binaries
      
      # Copy entire application source code to build area
      cp -r src/* "${{targets.destdir}}/app/"
      # Recursively copies all application source code from src to the package's /app directory
      
      # Copy pyproject.toml to app directory
      cp pyproject.toml "${{targets.destdir}}/app/"
      # Copies the Python project configuration file (with dependencies) to the app directory

  - name: "Install uv"
    # Second pipeline stage - installs the uv package manager

    runs: |
      # Install uv (Astral's fast Python package installer)
      curl -LsSf https://astral.sh/uv/install.sh | sh
      # Downloads and executes the uv installation script
      # -L follows redirects, -s is silent mode, -Sf shows errors
      
      # Source the environment to add uv to PATH
      . $HOME/.local/bin/env
      # Sources the environment file to make uv available in the current shell
      
      # Verify uv installation
      uv --version
      # Checks that uv was installed successfully by displaying its version

  - name: "Install Python dependencies with uv"
    # Third pipeline stage - installs all Python dependencies

    runs: |
      # Add uv to PATH
      export PATH="$HOME/.local/bin:$PATH"
      # Adds the uv installation directory to the PATH environment variable
      
      # Change to app directory
      cd "${{targets.destdir}}/app"
      # Changes working directory to where the application code was copied
      
      # Create virtual environment using uv
      uv venv venv --python 3.12
      # Creates a Python virtual environment named "venv" using Python 3.12
      
      # Activate the virtual environment
      . venv/bin/activate
      # Activates the virtual environment so packages install there
      
      # Install dependencies from pyproject.toml
      uv pip install --no-cache .
      # Installs all dependencies specified in pyproject.toml in the current directory
      # --no-cache prevents caching downloaded packages to save disk space
      
      # Generate a lock file for reproducibility
      uv pip freeze > requirements.lock
      # Creates a lock file with exact versions of all installed packages
      # This ensures consistent builds across different environments
      
      # Clean up unnecessary files to reduce image size
      find venv -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
      # Finds and removes all __pycache__ directories (Python bytecode cache)
      # 2>/dev/null suppresses errors, || true ensures command doesn't fail the build

      find venv -name "*.pyc" -delete 2>/dev/null || true
      # Finds and deletes all .pyc files (compiled Python bytecode)

      find venv -name "*.pyo" -delete 2>/dev/null || true
      # Finds and deletes all .pyo files (optimized Python bytecode)
      
      # Remove test directories
      find venv -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
      # Removes all directories named "tests" to save space

      find venv -type d -name "test" -exec rm -rf {} + 2>/dev/null || true
      # Removes all directories named "test" to save space
      
      # Remove .git directories if any
      find venv -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true
      # Removes any git repositories that might be in dependencies

  - name: "Create entrypoint script"
    # Fourth pipeline stage - creates the script that will run the application

    runs: |
      # Create the run script
      cat > "${{targets.destdir}}/app/run.sh" << 'EOF'
      # Creates a shell script using a heredoc (EOF delimiter)
      # Single quotes around 'EOF' prevent variable expansion in the heredoc

      #!/bin/sh
      # Shebang line - tells the system to execute this script with /bin/sh

      set -e
      # Exit immediately if any command fails (errexit option)
      
      # Activate virtual environment
      . /app/venv/bin/activate
      # Sources the virtual environment activation script
      
      # Set PYTHONPATH to include the app directory
      export PYTHONPATH=/app:$PYTHONPATH
      # Adds /app to Python's module search path so imports work correctly
      
      # Start the FastAPI application with uvicorn
      exec python -m uvicorn main:app --host 0.0.0.0 --port 8000
      # Executes uvicorn ASGI server to run the FastAPI application
      # main:app means import the 'app' object from 'main.py'
      # --host 0.0.0.0 binds to all network interfaces (allows external access)
      # --port 8000 specifies the port to listen on
      # exec replaces the shell process with the Python process (becomes PID 1)

      EOF
      # End of heredoc
      
      # Make it executable
      chmod +x "${{targets.destdir}}/app/run.sh"
      # Sets execute permission on the run script so it can be executed
      
      # Create a symlink for easier execution
      ln -s /app/run.sh "${{targets.destdir}}/usr/local/bin/fastapi-app"
      # Creates a symbolic link in /usr/local/bin pointing to the run script
      # This allows running the app with just "fastapi-app" command from anywhere

  - name: "Set permissions"
    # Fifth pipeline stage - sets appropriate file permissions for security

    runs: |
      # Set appropriate permissions on app directory
      chmod -R 755 "${{targets.destdir}}/app"
      # Recursively sets permissions: owner can read/write/execute, others can read/execute
      # 755 = rwxr-xr-x
      
      # Make run script read and execute only (immutable)
      chmod 555 "${{targets.destdir}}/app/run.sh"
      # Sets run script to read/execute only (no write) for security
      # 555 = r-xr-xr-x (no one can modify it)
      
      # Make Python files readable
      find "${{targets.destdir}}/app" -name "*.py" -exec chmod 644 {} \;
      # Sets all Python files to read/write for owner, read-only for others
      # 644 = rw-r--r--
      
      # Make lock file readable
      chmod 644 "${{targets.destdir}}/app/requirements.lock" 2>/dev/null || true
      # Sets lock file to read/write for owner, read-only for others
      # Ignores error if file doesn't exist

  - name: "Create system user configuration"
    # Sixth pipeline stage - creates user configuration metadata

    runs: |
      # Note: Actual user creation in APK is handled via install scripts
      mkdir -p "${{targets.destdir}}/etc"
      # Creates /etc directory for configuration files
      
      cat > "${{targets.destdir}}/etc/fastapi-app-user.conf" << EOF
      # Creates a configuration file with user information for the application

      # User configuration for fastapi-app
      USER=appuser
      # Defines the username that should run the application (non-root for security)

      UID=1001
      # Defines the user ID number (1001 is a common non-system UID)

      GID=1001
      # Defines the group ID number (matches UID for simplicity)

      HOME=/home/appuser
      # Defines the home directory for the application user

      EOF
      # End of heredoc

  - name: "Add package metadata"
    # Seventh and final pipeline stage - creates metadata files for traceability

    runs: |
      # Create a version file
      echo "1.0.0" > "${{targets.destdir}}/app/VERSION"
      # Writes version number to a VERSION file for runtime version checking
      
      # Create a package info file with lock file hash for traceability
      LOCK_HASH=$(sha256sum "${{targets.destdir}}/app/requirements.lock" 2>/dev/null | cut -d' ' -f1 || echo "none")
      # Calculates SHA256 hash of requirements.lock file for integrity verification
      # cut -d' ' -f1 extracts just the hash (first field) from sha256sum output
      # If file doesn't exist, outputs "none" instead

      cat > "${{targets.destdir}}/app/INFO" << EOF
      # Creates an INFO file with comprehensive package metadata

      Generic FastAPI Application
      # Application name displayed to users

      Version: 1.0.0
      # Version number of the application

      Built: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
      # Timestamp when package was built, in UTC timezone for consistency

      Python: 3.12
      # Python version used to build and run the application

      Package Manager: uv
      # Package manager used for dependency installation (uv is faster than pip)

      Lock File Hash: ${LOCK_HASH}
      # SHA256 hash of the requirements.lock file for verification and auditing

      EOF
      # End of heredoc