import paramiko
import os
import socket
import time
from contextlib import contextmanager

class SSHConnection:
    """
    A class to handle SSH connections to remote servers using paramiko.
    Supports password and key-based authentication, command execution, and file transfers.
    """
    
    def __init__(self, hostname, username, port=22, timeout=10):
        """
        Initialize SSH connection parameters.
        
        Args:
            hostname (str): Remote server hostname or IP address
            username (str): Username for authentication
            port (int): SSH port (default: 22)
            timeout (int): Connection timeout in seconds (default: 10)
        """
        self.hostname = hostname
        self.username = username
        self.port = port
        self.timeout = timeout
        self.ssh_client = None
        self.sftp_client = None
        
    def connect_with_password(self, password):
        """
        Connect to remote server using password authentication.
        
        Args:
            password (str): Password for authentication
            
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            self.ssh_client = paramiko.SSHClient()
            
            # Automatically add host keys (for testing purposes)
            # In production, you should verify host keys properly
            self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            # Connect to the server
            self.ssh_client.connect(
                hostname=self.hostname,
                port=self.port,
                username=self.username,
                password=password,
                timeout=self.timeout
            )
            
            print(f"Successfully connected to {self.hostname} as {self.username}")
            return True
            
        except paramiko.AuthenticationException:
            print("Authentication failed. Please check your credentials.")
            return False
        except paramiko.SSHException as e:
            print(f"SSH connection error: {e}")
            return False
        except socket.timeout:
            print(f"Connection timeout after {self.timeout} seconds")
            return False
        except Exception as e:
            print(f"Unexpected error: {e}")
            return False
    
    def connect_with_key(self, private_key_path, passphrase=None):
        """
        Connect to remote server using private key authentication.
        
        Args:
            private_key_path (str): Path to private key file
            passphrase (str): Passphrase for encrypted private key (optional)
            
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            self.ssh_client = paramiko.SSHClient()
            self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            # Load private key
            if private_key_path.endswith('.pem') or 'rsa' in private_key_path:
                private_key = paramiko.RSAKey.from_private_key_file(
                    private_key_path, password=passphrase
                )
            else:
                # Try to auto-detect key type
                try:
                    private_key = paramiko.RSAKey.from_private_key_file(
                        private_key_path, password=passphrase
                    )
                except paramiko.SSHException:
                    private_key = paramiko.DSSKey.from_private_key_file(
                        private_key_path, password=passphrase
                    )
            
            # Connect using private key
            self.ssh_client.connect(
                hostname=self.hostname,
                port=self.port,
                username=self.username,
                pkey=private_key,
                timeout=self.timeout
            )
            
            print(f"Successfully connected to {self.hostname} using private key")
            return True
            
        except FileNotFoundError:
            print(f"Private key file not found: {private_key_path}")
            return False
        except paramiko.AuthenticationException:
            print("Key-based authentication failed")
            return False
        except Exception as e:
            print(f"Error connecting with private key: {e}")
            return False
    
    def execute_command(self, command, timeout=30):
        """
        Execute a command on the remote server.
        
        Args:
            command (str): Command to execute
            timeout (int): Command timeout in seconds
            
        Returns:
            dict: Dictionary containing stdout, stderr, and exit_status
        """
        if not self.ssh_client:
            print("No active SSH connection. Please connect first.")
            return None
            
        try:
            # Execute command
            stdin, stdout, stderr = self.ssh_client.exec_command(command, timeout=timeout)
            
            # Get results
            exit_status = stdout.channel.recv_exit_status()
            stdout_data = stdout.read().decode('utf-8')
            stderr_data = stderr.read().decode('utf-8')
            
            return {
                'stdout': stdout_data,
                'stderr': stderr_data,
                'exit_status': exit_status
            }
            
        except paramiko.SSHException as e:
            print(f"SSH error executing command: {e}")
            return None
        except socket.timeout:
            print(f"Command timed out after {timeout} seconds")
            return None
        except Exception as e:
            print(f"Error executing command: {e}")
            return None
    
    def upload_file(self, local_path, remote_path):
        """
        Upload a file to the remote server.
        
        Args:
            local_path (str): Local file path
            remote_path (str): Remote file path
            
        Returns:
            bool: True if upload successful, False otherwise
        """
        try:
            if not self.sftp_client:
                self.sftp_client = self.ssh_client.open_sftp()
            
            # Check if local file exists
            if not os.path.exists(local_path):
                print(f"Local file not found: {local_path}")
                return False
            
            # Upload file
            self.sftp_client.put(local_path, remote_path)
            print(f"Successfully uploaded {local_path} to {remote_path}")
            return True
            
        except Exception as e:
            print(f"Error uploading file: {e}")
            return False
    
    def download_file(self, remote_path, local_path):
        """
        Download a file from the remote server.
        
        Args:
            remote_path (str): Remote file path
            local_path (str): Local file path
            
        Returns:
            bool: True if download successful, False otherwise
        """
        try:
            if not self.sftp_client:
                self.sftp_client = self.ssh_client.open_sftp()
            
            # Create local directory if it doesn't exist
            local_dir = os.path.dirname(local_path)
            if local_dir and not os.path.exists(local_dir):
                os.makedirs(local_dir)
            
            # Download file
            self.sftp_client.get(remote_path, local_path)
            print(f"Successfully downloaded {remote_path} to {local_path}")
            return True
            
        except Exception as e:
            print(f"Error downloading file: {e}")
            return False
    
    def list_directory(self, path='.'):
        """
        List contents of a directory on the remote server.
        
        Args:
            path (str): Directory path (default: current directory)
            
        Returns:
            list: List of file/directory names, or None if error
        """
        try:
            if not self.sftp_client:
                self.sftp_client = self.ssh_client.open_sftp()
            
            file_list = self.sftp_client.listdir(path)
            return file_list
            
        except Exception as e:
            print(f"Error listing directory: {e}")
            return None
    
    def close(self):
        """
        Close SSH and SFTP connections.
        """
        if self.sftp_client:
            self.sftp_client.close()
            self.sftp_client = None
            
        if self.ssh_client:
            self.ssh_client.close()
            self.ssh_client = None
            
        print("SSH connection closed")
    
    @contextmanager
    def connection_context(self, auth_method='password', **auth_kwargs):
        """
        Context manager for automatic connection cleanup.
        
        Args:
            auth_method (str): 'password' or 'key'
            **auth_kwargs: Authentication parameters
            
        Usage:
            with ssh.connection_context('password', password='your_password'):
                result = ssh.execute_command('ls -la')
        """
        try:
            if auth_method == 'password':
                success = self.connect_with_password(auth_kwargs['password'])
            elif auth_method == 'key':
                success = self.connect_with_key(
                    auth_kwargs['private_key_path'],
                    auth_kwargs.get('passphrase')
                )
            else:
                raise ValueError("auth_method must be 'password' or 'key'")
                
            if not success:
                raise Exception("Failed to establish SSH connection")
                
            yield self
            
        finally:
            self.close()


# Example usage and test functions
def test_ssh_connection():
    """
    Test function demonstrating how to use the SSHConnection class.
    """
    # Create SSH connection instance
    ssh = SSHConnection(
        hostname='your-server.com',  # Replace with your server
        username='your-username',    # Replace with your username
        port=22,
        timeout=10
    )
    
    # Test 1: Connect with password
    print("=== Testing Password Authentication ===")
    if ssh.connect_with_password('your-password'):  # Replace with your password
        
        # Execute a simple command
        result = ssh.execute_command('uname -a')
        if result:
            print(f"Command output: {result['stdout']}")
            print(f"Exit status: {result['exit_status']}")
        
        # List directory contents
        files = ssh.list_directory('/home/your-username')  # Replace with your path
        if files:
            print(f"Directory contents: {files}")
        
        # Close connection
        ssh.close()
    
    # Test 2: Connect with private key (uncomment and modify as needed)
    """
    print("\n=== Testing Key Authentication ===")
    if ssh.connect_with_key('/path/to/your/private/key.pem'):
        result = ssh.execute_command('whoami')
        if result:
            print(f"Current user: {result['stdout'].strip()}")
        ssh.close()
    """
    
    # Test 3: Using context manager
    print("\n=== Testing Context Manager ===")
    try:
        with ssh.connection_context('password', password='your-password'):
            result = ssh.execute_command('date')
            if result:
                print(f"Server time: {result['stdout'].strip()}")
    except Exception as e:
        print(f"Context manager test failed: {e}")


if __name__ == "__main__":
    # Run tests (modify connection parameters first)
    print("SSH Connection Test")
    print("Please modify the connection parameters in test_ssh_connection() function")
    print("before running this script.")
    
    # Uncomment the line below after modifying connection parameters
    # test_ssh_connection()


###############
import paramiko
import os
import socket
import time
from contextlib import contextmanager

class SSHConnection:
    """
    A class to handle SSH connections to remote servers using paramiko.
    Supports password and key-based authentication, command execution, and file transfers.
    """
    
    def __init__(self, hostname, username, port=22, timeout=10):
        """
        Initialize SSH connection parameters.
        
        Args:
            hostname (str): Remote server hostname or IP address
            username (str): Username for authentication
            port (int): SSH port (default: 22)
            timeout (int): Connection timeout in seconds (default: 10)
        """
        self.hostname = hostname
        self.username = username
        self.port = port
        self.timeout = timeout
        self.ssh_client = None
        self.sftp_client = None
        
    def connect_with_password(self, password):
        """
        Connect to remote server using password authentication.
        
        Args:
            password (str): Password for authentication
            
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            self.ssh_client = paramiko.SSHClient()
            
            # Automatically add host keys (for testing purposes)
            # In production, you should verify host keys properly
            self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            # Connect to the server
            self.ssh_client.connect(
                hostname=self.hostname,
                port=self.port,
                username=self.username,
                password=password,
                timeout=self.timeout
            )
            
            print(f"Successfully connected to {self.hostname} as {self.username}")
            return True
            
        except paramiko.AuthenticationException:
            print("Authentication failed. Please check your credentials.")
            return False
        except paramiko.SSHException as e:
            print(f"SSH connection error: {e}")
            return False
        except socket.timeout:
            print(f"Connection timeout after {self.timeout} seconds")
            return False
        except Exception as e:
            print(f"Unexpected error: {e}")
            return False
    
    def connect_with_key(self, private_key_path, passphrase=None):
        """
        Connect to remote server using private key authentication.
        
        Args:
            private_key_path (str): Path to private key file
            passphrase (str): Passphrase for encrypted private key (optional)
            
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            self.ssh_client = paramiko.SSHClient()
            self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            # Load private key
            if private_key_path.endswith('.pem') or 'rsa' in private_key_path:
                private_key = paramiko.RSAKey.from_private_key_file(
                    private_key_path, password=passphrase
                )
            else:
                # Try to auto-detect key type
                try:
                    private_key = paramiko.RSAKey.from_private_key_file(
                        private_key_path, password=passphrase
                    )
                except paramiko.SSHException:
                    private_key = paramiko.DSSKey.from_private_key_file(
                        private_key_path, password=passphrase
                    )
            
            # Connect using private key
            self.ssh_client.connect(
                hostname=self.hostname,
                port=self.port,
                username=self.username,
                pkey=private_key,
                timeout=self.timeout
            )
            
            print(f"Successfully connected to {self.hostname} using private key")
            return True
            
        except FileNotFoundError:
            print(f"Private key file not found: {private_key_path}")
            return False
        except paramiko.AuthenticationException:
            print("Key-based authentication failed")
            return False
        except Exception as e:
            print(f"Error connecting with private key: {e}")
            return False
    
    def execute_command(self, command, timeout=30):
        """
        Execute a command on the remote server.
        
        Args:
            command (str): Command to execute
            timeout (int): Command timeout in seconds
            
        Returns:
            dict: Dictionary containing stdout, stderr, and exit_status
        """
        if not self.ssh_client:
            print("No active SSH connection. Please connect first.")
            return None
            
        try:
            # Execute command
            stdin, stdout, stderr = self.ssh_client.exec_command(command, timeout=timeout)
            
            # Get results
            exit_status = stdout.channel.recv_exit_status()
            stdout_data = stdout.read().decode('utf-8')
            stderr_data = stderr.read().decode('utf-8')
            
            return {
                'stdout': stdout_data,
                'stderr': stderr_data,
                'exit_status': exit_status
            }
            
        except paramiko.SSHException as e:
            print(f"SSH error executing command: {e}")
            return None
        except socket.timeout:
            print(f"Command timed out after {timeout} seconds")
            return None
        except Exception as e:
            print(f"Error executing command: {e}")
            return None
    
    def upload_file(self, local_path, remote_path):
        """
        Upload a file to the remote server.
        
        Args:
            local_path (str): Local file path
            remote_path (str): Remote file path
            
        Returns:
            bool: True if upload successful, False otherwise
        """
        try:
            if not self.sftp_client:
                self.sftp_client = self.ssh_client.open_sftp()
            
            # Check if local file exists
            if not os.path.exists(local_path):
                print(f"Local file not found: {local_path}")
                return False
            
            # Upload file
            self.sftp_client.put(local_path, remote_path)
            print(f"Successfully uploaded {local_path} to {remote_path}")
            return True
            
        except Exception as e:
            print(f"Error uploading file: {e}")
            return False
    
    def download_file(self, remote_path, local_path):
        """
        Download a file from the remote server.
        
        Args:
            remote_path (str): Remote file path
            local_path (str): Local file path
            
        Returns:
            bool: True if download successful, False otherwise
        """
        try:
            if not self.sftp_client:
                self.sftp_client = self.ssh_client.open_sftp()
            
            # Create local directory if it doesn't exist
            local_dir = os.path.dirname(local_path)
            if local_dir and not os.path.exists(local_dir):
                os.makedirs(local_dir)
            
            # Download file
            self.sftp_client.get(remote_path, local_path)
            print(f"Successfully downloaded {remote_path} to {local_path}")
            return True
            
        except Exception as e:
            print(f"Error downloading file: {e}")
            return False
    
    def list_directory(self, path='.'):
        """
        List contents of a directory on the remote server.
        
        Args:
            path (str): Directory path (default: current directory)
            
        Returns:
            list: List of file/directory names, or None if error
        """
        try:
            if not self.sftp_client:
                self.sftp_client = self.ssh_client.open_sftp()
            
            file_list = self.sftp_client.listdir(path)
            return file_list
            
        except Exception as e:
            print(f"Error listing directory: {e}")
            return None
    
    def close(self):
        """
        Close SSH and SFTP connections.
        """
        if self.sftp_client:
            self.sftp_client.close()
            self.sftp_client = None
            
        if self.ssh_client:
            self.ssh_client.close()
            self.ssh_client = None
            
        print("SSH connection closed")
    
    @contextmanager
    def connection_context(self, auth_method='password', **auth_kwargs):
        """
        Context manager for automatic connection cleanup.
        
        Args:
            auth_method (str): 'password' or 'key'
            **auth_kwargs: Authentication parameters
            
        Usage:
            with ssh.connection_context('password', password='your_password'):
                result = ssh.execute_command('ls -la')
        """
        try:
            if auth_method == 'password':
                success = self.connect_with_password(auth_kwargs['password'])
            elif auth_method == 'key':
                success = self.connect_with_key(
                    auth_kwargs['private_key_path'],
                    auth_kwargs.get('passphrase')
                )
            else:
                raise ValueError("auth_method must be 'password' or 'key'")
                
            if not success:
                raise Exception("Failed to establish SSH connection")
                
            yield self
            
        finally:
            self.close()


# Example usage and test functions
def test_ssh_connection():
    """
    Test function demonstrating how to use the SSHConnection class.
    """
    # Create SSH connection instance
    ssh = SSHConnection(
        hostname='your-server.com',  # Replace with your server
        username='your-username',    # Replace with your username
        port=22,
        timeout=10
    )
    
    # Test 1: Connect with password
    print("=== Testing Password Authentication ===")
    if ssh.connect_with_password('your-password'):  # Replace with your password
        
        # Execute a simple command
        result = ssh.execute_command('uname -a')
        if result:
            print(f"Command output: {result['stdout']}")
            print(f"Exit status: {result['exit_status']}")
        
        # List directory contents
        files = ssh.list_directory('/home/your-username')  # Replace with your path
        if files:
            print(f"Directory contents: {files}")
        
        # Close connection
        ssh.close()
    
    # Test 2: Connect with private key (uncomment and modify as needed)
    """
    print("\n=== Testing Key Authentication ===")
    if ssh.connect_with_key('/path/to/your/private/key.pem'):
        result = ssh.execute_command('whoami')
        if result:
            print(f"Current user: {result['stdout'].strip()}")
        ssh.close()
    """
    
    # Test 3: Using context manager
    print("\n=== Testing Context Manager ===")
    try:
        with ssh.connection_context('password', password='your-password'):
            result = ssh.execute_command('date')
            if result:
                print(f"Server time: {result['stdout'].strip()}")
    except Exception as e:
        print(f"Context manager test failed: {e}")


def demonstrate_command_execution():
    """
    Demonstrate various command execution capabilities on remote server.
    """
    # Replace with your actual connection details
    ssh = SSHConnection('your-server.com', 'your-username')
    
    if ssh.connect_with_password('your-password'):
        print("=== Remote Command Execution Examples ===")
        
        # Basic system information commands
        commands = [
            'whoami',           # Current user
            'pwd',              # Current directory
            'uname -a',         # System information
            'date',             # Current date/time
            'uptime',           # System uptime
            'df -h',            # Disk usage
            'free -h',          # Memory usage
            'ps aux | head -10' # Running processes
        ]
        
        for cmd in commands:
            print(f"\n--- Executing: {cmd} ---")
            result = ssh.execute_command(cmd)
            if result:
                if result['exit_status'] == 0:
                    print(f"Success: {result['stdout'].strip()}")
                else:
                    print(f"Error: {result['stderr'].strip()}")
        
        # File operations
        print("\n=== File Operations ===")
        
        # Create a test file
        create_result = ssh.execute_command('echo "Hello from remote server" > /tmp/test_file.txt')
        if create_result and create_result['exit_status'] == 0:
            print("Test file created successfully")
        
        # Read the file
        read_result = ssh.execute_command('cat /tmp/test_file.txt')
        if read_result and read_result['exit_status'] == 0:
            print(f"File contents: {read_result['stdout'].strip()}")
        
        # List files in /tmp
        ls_result = ssh.execute_command('ls -la /tmp/test_file.txt')
        if ls_result and ls_result['exit_status'] == 0:
            print(f"File info: {ls_result['stdout'].strip()}")
        
        # Clean up
        ssh.execute_command('rm -f /tmp/test_file.txt')
        
        # Directory operations
        print("\n=== Directory Operations ===")
        
        # Create directory
        ssh.execute_command('mkdir -p /tmp/test_dir')
        
        # Change to directory and list contents
        result = ssh.execute_command('cd /tmp/test_dir && pwd')
        if result:
            print(f"Changed to directory: {result['stdout'].strip()}")
        
        # Clean up directory
        ssh.execute_command('rm -rf /tmp/test_dir')
        
        # Network commands
        print("\n=== Network Commands ===")
        
        # Check network interfaces
        ifconfig_result = ssh.execute_command('ip addr show | grep inet')
        if ifconfig_result and ifconfig_result['exit_status'] == 0:
            print(f"Network interfaces:\n{ifconfig_result['stdout']}")
        
        # Package management (works on Ubuntu/Debian)
        print("\n=== Package Management (if applicable) ===")
        
        # Check if apt is available
        apt_result = ssh.execute_command('which apt')
        if apt_result and apt_result['exit_status'] == 0:
            # Update package list (might require sudo)
            update_result = ssh.execute_command('apt list --upgradable 2>/dev/null | head -5')
            if update_result:
                print(f"Available updates:\n{update_result['stdout']}")
        
        # Service management
        print("\n=== Service Management ===")
        
        # Check if systemctl is available
        systemctl_result = ssh.execute_command('which systemctl')
        if systemctl_result and systemctl_result['exit_status'] == 0:
            # List running services
            services_result = ssh.execute_command('systemctl list-units --type=service --state=running | head -10')
            if services_result:
                print(f"Running services:\n{services_result['stdout']}")
        
        # Long running command example
        print("\n=== Long Running Command Example ===")
        
        # Execute a command that takes some time
        long_cmd_result = ssh.execute_command('sleep 3 && echo "Command completed after 3 seconds"')
        if long_cmd_result and long_cmd_result['exit_status'] == 0:
            print(f"Long command result: {long_cmd_result['stdout'].strip()}")
        
        ssh.close()
    else:
        print("Failed to connect to remote server")


def interactive_command_executor():
    """
    Interactive command executor for remote server.
    """
    ssh = SSHConnection('your-server.com', 'your-username')
    
    if ssh.connect_with_password('your-password'):
        print("Connected to remote server. Type 'exit' to quit.")
        
        while True:
            try:
                command = input("remote$ ")
                
                if command.lower() in ['exit', 'quit']:
                    break
                    
                if command.strip() == '':
                    continue
                
                result = ssh.execute_command(command)
                if result:
                    if result['stdout']:
                        print(result['stdout'], end='')
                    if result['stderr']:
                        print(f"ERROR: {result['stderr']}", end='')
                    if result['exit_status'] != 0:
                        print(f"Command exited with status: {result['exit_status']}")
                
            except KeyboardInterrupt:
                print("\nInterrupted by user")
                break
            except Exception as e:
                print(f"Error: {e}")
        
        ssh.close()
        print("Connection closed.")
    else:
        print("Failed to connect to remote server")


if __name__ == "__main__":
    # Run tests (modify connection parameters first)
    print("SSH Connection Test")
    print("Please modify the connection parameters in test_ssh_connection() function")
    print("before running this script.")
    
    # Uncomment the line below after modifying connection parameters
    # test_ssh_connection()