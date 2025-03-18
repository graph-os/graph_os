# GraphOS CLI

GraphOS CLI is a terminal user interface (TUI) client for GraphOS, providing an interactive way to explore and manipulate GraphOS data and services from the terminal.

## Components

The CLI connects to GraphOS services through the GraphOS Protocol layer (primarily gRPC), and provides various UIs for interacting with graphs, code, components, and other GraphOS resources.

## Development

### Building

```bash
cd apps/graph_os_cli
cargo build
```

### Running

```bash
cd apps/graph_os_cli
cargo run
```

## Authentication

The GraphOS CLI requires authentication when connecting to GraphOS protocol services. Authentication is handled through a secure configuration system:

### Configuration Files

The CLI looks for configuration files in the following locations (in order of precedence):

1. `/etc/graph_os/*.{json,yaml,toml}` - System-wide configuration
2. `~/.graph_os/*.{json,yaml,toml}` - User-specific configuration

### Setting Up Authentication

```bash
# Initialize a new configuration file
gos config init

# Set the RPC secret (stored securely in the config file)
gos config set-secret "your_secret_here"

# Configure an endpoint
gos config set-endpoint default --url api.example.com --secret "endpoint_secret" --use-tls

# View your current configuration
gos config show
```

### Configuration Formats

The CLI supports multiple configuration formats:

```bash
# Create configuration in TOML format (default)
gos config init

# Create configuration in JSON format
gos config init --format json

# Create configuration in YAML format
gos config init --format yaml
```

### Using with GraphOS Services

Once configured, the CLI will automatically use the stored secrets for authentication:

```bash
# Start the CLI (uses configured secret automatically)
gos

# Specify a session to resume
gos --session 123e4567-e89b-12d3-a456-426614174000
```

### Security Notes

- Secrets are stored only in the secure configuration files
- Secrets are never passed as command-line arguments or stored in environment variables
- Configuration files should have appropriate permissions (600 or 400)
- For secure communication with GraphOS services, consider:
  - Using Unix sockets for local-only communication
  - TLS certificates for encrypted remote connections
  - Network-level security (VPNs, firewalls) for production deployments

For full API documentation, see the GraphOS Protocol documentation.