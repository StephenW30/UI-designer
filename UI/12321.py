import sys
import os
import threading
import time
try:
    import paramiko
    PARAMIKO_AVAILABLE = True
except ImportError:
    PARAMIKO_AVAILABLE = False
    print("Warning: paramiko not installed. Run: pip install paramiko")

try:
    import GPUtil
    GPUTIL_AVAILABLE = True
except ImportError:
    GPUTIL_AVAILABLE = False
    print("Warning: GPUtil not installed. Run: pip install GPUtil")

from PyQt5.QtWidgets import *
from PyQt5.QtCore import *
from PyQt5.QtGui import *

class ServerConnectionWidget(QWidget):
    """Server Connection Module"""
    connection_status_changed = pyqtSignal(bool, str)
    ssh_client_changed = pyqtSignal(object)  # Signal to pass SSH client to other modules
    
    def __init__(self):
        super().__init__()
        self.ssh_client = None
        self.sftp_client = None
        self.is_connected = False
        self.init_ui()
        
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setSpacing(10)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Check paramiko availability
        if not PARAMIKO_AVAILABLE:
            error_label = QLabel("Error: paramiko not installed\nRun: pip install paramiko")
            error_label.setStyleSheet("color: red; font-weight: bold;")
            layout.addWidget(error_label)
            self.setLayout(layout)
            return
        
        # Title
        title = QLabel("Server Connection")
        title.setFont(QFont("Arial", 14, QFont.Bold))
        layout.addWidget(title)
        
        # Connection form
        form_layout = QFormLayout()
        
        self.ip_input = QLineEdit()
        self.ip_input.setPlaceholderText("192.168.1.100")
        
        self.username_input = QLineEdit()
        self.username_input.setPlaceholderText("username")
        
        self.password_input = QLineEdit()
        self.password_input.setEchoMode(QLineEdit.Password)
        self.password_input.setPlaceholderText("password")
        
        # Port input
        self.port_input = QLineEdit("22")
        self.port_input.setPlaceholderText("22")
        
        form_layout.addRow("IP Address:", self.ip_input)
        form_layout.addRow("Username:", self.username_input)
        form_layout.addRow("Password:", self.password_input)
        form_layout.addRow("Port:", self.port_input)
        
        layout.addLayout(form_layout)
        
        # Connect button
        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self.toggle_connection)
        layout.addWidget(self.connect_btn)
        
        # Test connection button
        self.test_btn = QPushButton("Test Connection")
        self.test_btn.clicked.connect(self.test_connection)
        layout.addWidget(self.test_btn)
        
        # Status display
        self.status_label = QLabel("Status: Not Connected")
        layout.addWidget(self.status_label)
        
        # Info display
        self.info_text = QTextEdit()
        self.info_text.setMaximumHeight(120)
        self.info_text.setReadOnly(True)
        layout.addWidget(self.info_text)
        
        layout.addStretch()
        self.setLayout(layout)
        
    def toggle_connection(self):
        """Toggle connection state"""
        if self.is_connected:
            self.disconnect_from_server()
        else:
            self.connect_to_server()
            
    def test_connection(self):
        """Test connection without establishing permanent connection"""
        ip = self.ip_input.text().strip()
        username = self.username_input.text().strip()
        password = self.password_input.text().strip()
        port = int(self.port_input.text().strip()) if self.port_input.text().strip() else 22
        
        if not all([ip, username, password]):
            self.show_error("Please fill in all fields")
            return
            
        self.test_btn.setEnabled(False)
        self.test_btn.setText("Testing...")
        self.info_text.append("Testing connection...")
        
        # Test in new thread
        thread = threading.Thread(target=self._test_thread, args=(ip, username, password, port))
        thread.daemon = True
        thread.start()
        
    def connect_to_server(self):
        """Connect to server"""
        if not PARAMIKO_AVAILABLE:
            self.show_error("paramiko not available")
            return
            
        ip = self.ip_input.text().strip()
        username = self.username_input.text().strip()
        password = self.password_input.text().strip()
        port = int(self.port_input.text().strip()) if self.port_input.text().strip() else 22
        
        if not all([ip, username, password]):
            self.show_error("Please fill in all fields")
            return
            
        self.connect_btn.setEnabled(False)
        self.connect_btn.setText("Connecting...")
        self.info_text.append(f"Connecting to {ip}:{port}...")
        
        # Connect in new thread
        thread = threading.Thread(target=self._connect_thread, args=(ip, username, password, port))
        thread.daemon = True
        thread.start()
        
    def disconnect_from_server(self):
        """Disconnect from server"""
        try:
            if self.sftp_client:
                self.sftp_client.close()
            if self.ssh_client:
                self.ssh_client.close()
        except:
            pass
        
        self.ssh_client = None
        self.sftp_client = None
        self.is_connected = False
        
        self.status_label.setText("Status: Disconnected")
        self.info_text.append("Disconnected from server")
        self.connect_btn.setText("Connect")
        self.connect_btn.setEnabled(True)
        self.connection_status_changed.emit(False, "")
        self.ssh_client_changed.emit(None)
        
    def _test_thread(self, ip, username, password, port):
        """Test connection thread"""
        try:
            test_client = paramiko.SSHClient()
            test_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            test_client.connect(ip, port=port, username=username, password=password, timeout=10)
            
            # Test basic command
            stdin, stdout, stderr = test_client.exec_command('echo "Connection test successful"')
            result = stdout.read().decode().strip()
            
            test_client.close()
            
            QTimer.singleShot(0, lambda: self.test_success(result))
            
        except Exception as e:
            QTimer.singleShot(0, lambda: self.test_failed(str(e)))
            
    def _connect_thread(self, ip, username, password, port):
        """Connection thread"""
        try:
            self.ssh_client = paramiko.SSHClient()
            self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.ssh_client.connect(ip, port=port, username=username, password=password, timeout=10)
            
            # Test the connection
            stdin, stdout, stderr = self.ssh_client.exec_command('whoami')
            user_result = stdout.read().decode().strip()
            
            # Open SFTP
            self.sftp_client = self.ssh_client.open_sftp()
            
            QTimer.singleShot(0, lambda: self.connection_success(ip, username, port, user_result))
            
        except Exception as e:
            QTimer.singleShot(0, lambda: self.connection_failed(str(e)))
            
    def test_success(self, result):
        """Test successful"""
        self.info_text.append(f"Test result: {result}")
        self.test_btn.setText("Test Connection")
        self.test_btn.setEnabled(True)
        
    def test_failed(self, error):
        """Test failed"""
        self.info_text.append(f"Test failed: {error}")
        self.test_btn.setText("Test Connection")
        self.test_btn.setEnabled(True)
        
    def connection_success(self, ip, username, port, user_result):
        """Connection successful"""
        self.is_connected = True
        self.status_label.setText("Status: Connected")
        self.info_text.append(f"Connected to {ip}:{port} as {username}")
        self.info_text.append(f"Remote user: {user_result}")
        self.connect_btn.setText("Disconnect")
        self.connect_btn.setEnabled(True)
        self.connection_status_changed.emit(True, f"{ip}:{port}")
        self.ssh_client_changed.emit(self.ssh_client)
        
    def connection_failed(self, error):
        """Connection failed"""
        self.show_error(f"Connection failed: {error}")
        self.connect_btn.setText("Connect")
        self.connect_btn.setEnabled(True)
        self.ssh_client = None
        self.sftp_client = None
        self.is_connected = False
        
    def show_error(self, message):
        """Show error message"""
        self.status_label.setText(f"Status: {message}")
        self.info_text.append(f"Error: {message}")
        
    def get_ssh_client(self):
        """Get current SSH client"""
        return self.ssh_client if self.is_connected else None
        

class FileTransferWidget(QWidget):
    """File Transfer Module"""
    
    def __init__(self):
        super().__init__()
        self.local_path = ""
        self.remote_path = "/tmp/"
        self.ssh_client = None
        self.sftp_client = None
        self.init_ui()
        
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setSpacing(10)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Title
        title = QLabel("File Transfer")
        title.setFont(QFont("Arial", 14, QFont.Bold))
        layout.addWidget(title)
        
        # Connection status
        self.connection_status = QLabel("No SSH connection available")
        self.connection_status.setStyleSheet("color: orange; font-weight: bold;")
        layout.addWidget(self.connection_status)
        
        # Local file selection
        local_group = QGroupBox("Local Dataset")
        local_layout = QVBoxLayout()
        
        self.local_path_label = QLabel("No folder selected")
        self.select_folder_btn = QPushButton("Select Folder")
        self.select_folder_btn.clicked.connect(self.select_local_folder)
        
        local_layout.addWidget(self.local_path_label)
        local_layout.addWidget(self.select_folder_btn)
        local_group.setLayout(local_layout)
        layout.addWidget(local_group)
        
        # Remote path setting
        remote_group = QGroupBox("Remote Path")
        remote_layout = QVBoxLayout()
        
        self.remote_path_input = QLineEdit(self.remote_path)
        self.remote_path_input.textChanged.connect(lambda text: setattr(self, 'remote_path', text))
        
        remote_layout.addWidget(QLabel("Remote directory:"))
        remote_layout.addWidget(self.remote_path_input)
        remote_group.setLayout(remote_layout)
        layout.addWidget(remote_group)
        
        # Upload operation
        upload_group = QGroupBox("Upload")
        upload_layout = QVBoxLayout()
        
        self.upload_btn = QPushButton("Upload Dataset")
        self.upload_btn.clicked.connect(self.upload_dataset)
        self.upload_btn.setEnabled(False)
        
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        
        self.upload_status = QLabel("")
        
        upload_layout.addWidget(self.upload_btn)
        upload_layout.addWidget(self.progress_bar)
        upload_layout.addWidget(self.upload_status)
        upload_group.setLayout(upload_layout)
        layout.addWidget(upload_group)
        
        layout.addStretch()
        self.setLayout(layout)
        
    def set_ssh_client(self, ssh_client):
        """Set SSH client for file transfer"""
        self.ssh_client = ssh_client
        if ssh_client:
            try:
                self.sftp_client = ssh_client.open_sftp()
                self.connection_status.setText("SSH connection available")
                self.connection_status.setStyleSheet("color: green; font-weight: bold;")
                self.update_upload_button_state()
            except Exception as e:
                self.connection_status.setText(f"SFTP error: {str(e)}")
                self.connection_status.setStyleSheet("color: red; font-weight: bold;")
                self.sftp_client = None
        else:
            self.connection_status.setText("No SSH connection available")
            self.connection_status.setStyleSheet("color: orange; font-weight: bold;")
            self.sftp_client = None
            self.upload_btn.setEnabled(False)
            
    def update_upload_button_state(self):
        """Update upload button state based on connection and folder selection"""
        self.upload_btn.setEnabled(bool(self.local_path and self.sftp_client))
        
    def select_local_folder(self):
        """Select local folder"""
        folder = QFileDialog.getExistingDirectory(self, "Select Dataset Folder")
        if folder:
            self.local_path = folder
            self.local_path_label.setText(f"Selected: {os.path.basename(folder)}")
            self.update_upload_button_state()
            
    def upload_dataset(self):
        """Upload dataset"""
        if not self.local_path:
            QMessageBox.warning(self, "Warning", "Please select a dataset folder first")
            return
            
        if not self.sftp_client:
            QMessageBox.warning(self, "Warning", "No SFTP connection available")
            return
            
        self.upload_btn.setEnabled(False)
        self.progress_bar.setVisible(True)
        self.upload_status.setText("Starting upload...")
        
        # Start real upload process
        thread = threading.Thread(target=self._upload_thread)
        thread.daemon = True
        thread.start()
        
    def _upload_thread(self):
        """Real upload thread"""
        try:
            import tarfile
            import tempfile
            
            # Create temporary tar file
            QTimer.singleShot(0, lambda: self.update_upload_progress(10, "Creating archive..."))
            
            with tempfile.NamedTemporaryFile(suffix='.tar.gz', delete=False) as temp_file:
                temp_tar_path = temp_file.name
                
            # Create tar archive
            with tarfile.open(temp_tar_path, 'w:gz') as tar:
                tar.add(self.local_path, arcname=os.path.basename(self.local_path))
                
            QTimer.singleShot(0, lambda: self.update_upload_progress(30, "Archive created, uploading..."))
            
            # Upload file
            remote_tar_path = f"{self.remote_path}/{os.path.basename(self.local_path)}.tar.gz"
            
            file_size = os.path.getsize(temp_tar_path)
            uploaded = 0
            
            def progress_callback(transferred, total):
                progress = int(30 + (transferred / total) * 50)
                QTimer.singleShot(0, lambda: self.update_upload_progress(progress, f"Uploading... {transferred}/{total} bytes"))
            
            self.sftp_client.put(temp_tar_path, remote_tar_path, callback=progress_callback)
            
            QTimer.singleShot(0, lambda: self.update_upload_progress(80, "Upload complete, extracting..."))
            
            # Extract on remote server
            extract_cmd = f"cd {self.remote_path} && tar -xzf {os.path.basename(remote_tar_path)} && rm {os.path.basename(remote_tar_path)}"
            stdin, stdout, stderr = self.ssh_client.exec_command(extract_cmd)
            
            # Wait for extraction to complete
            exit_status = stdout.channel.recv_exit_status()
            
            # Clean up local temp file
            os.unlink(temp_tar_path)
            
            if exit_status == 0:
                QTimer.singleShot(0, lambda: self.update_upload_progress(100, "Upload and extraction completed successfully"))
            else:
                error_msg = stderr.read().decode().strip()
                QTimer.singleShot(0, lambda: self.upload_failed(f"Extraction failed: {error_msg}"))
                
        except Exception as e:
            QTimer.singleShot(0, lambda: self.upload_failed(str(e)))
            
    def update_upload_progress(self, value, message):
        """Update upload progress"""
        self.progress_bar.setValue(value)
        self.upload_status.setText(message)
        
        if value >= 100:
            self.upload_btn.setEnabled(True)
            QTimer.singleShot(3000, lambda: self.progress_bar.setVisible(False))
            
    def upload_failed(self, error):
        """Upload failed"""
        self.upload_status.setText(f"Upload failed: {error}")
        self.progress_bar.setValue(0)
        self.upload_btn.setEnabled(True)
        QTimer.singleShot(5000, lambda: self.progress_bar.setVisible(False))

class GPUSelectionWidget(QWidget):
    """GPU Selection Module"""
    
    def __init__(self):
        super().__init__()
        self.selected_gpu = None
        self.gpu_info = []
        self.ssh_client = None
        self.init_ui()
        
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setSpacing(10)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Title
        title = QLabel("GPU Selection")
        title.setFont(QFont("Arial", 14, QFont.Bold))
        layout.addWidget(title)
        
        # Connection status
        self.connection_status = QLabel("No SSH connection available")
        self.connection_status.setStyleSheet("color: orange; font-weight: bold;")
        layout.addWidget(self.connection_status)
        
        # Refresh button
        refresh_btn = QPushButton("Refresh GPU Info")
        refresh_btn.clicked.connect(self.refresh_gpu_info)
        layout.addWidget(refresh_btn)
        
        # GPU list
        self.gpu_scroll = QScrollArea()
        self.gpu_widget = QWidget()
        self.gpu_layout = QVBoxLayout()
        
        self.gpu_widget.setLayout(self.gpu_layout)
        self.gpu_scroll.setWidget(self.gpu_widget)
        self.gpu_scroll.setWidgetResizable(True)
        
        layout.addWidget(self.gpu_scroll)
        
        # Selection info
        self.selection_label = QLabel("No GPU selected")
        layout.addWidget(self.selection_label)
        
        layout.addStretch()
        self.setLayout(layout)
        
        # Initial state
        self.show_no_connection()
        
    def set_ssh_client(self, ssh_client):
        """Set SSH client for remote GPU detection"""
        self.ssh_client = ssh_client
        if ssh_client:
            self.connection_status.setText("SSH connection available")
            self.connection_status.setStyleSheet("color: green; font-weight: bold;")
            self.refresh_gpu_info()
        else:
            self.connection_status.setText("No SSH connection available")
            self.connection_status.setStyleSheet("color: orange; font-weight: bold;")
            self.show_no_connection()
            
    def show_no_connection(self):
        """Show no connection message"""
        # Clear existing GPU cards
        for i in reversed(range(self.gpu_layout.count())):
            self.gpu_layout.itemAt(i).widget().setParent(None)
            
        no_conn_label = QLabel("Please connect to a remote server first")
        no_conn_label.setStyleSheet("padding: 20px; text-align: center; color: gray; font-style: italic;")
        self.gpu_layout.addWidget(no_conn_label)
        
    def refresh_gpu_info(self):
        """Refresh GPU information using remote nvidia-smi"""
        if not self.ssh_client:
            self.show_no_connection()
            return
            
        # Clear existing GPU cards
        for i in reversed(range(self.gpu_layout.count())):
            self.gpu_layout.itemAt(i).widget().setParent(None)
            
        loading_label = QLabel("Loading GPU information...")
        self.gpu_layout.addWidget(loading_label)
        
        # Get GPU info in thread
        thread = threading.Thread(target=self._get_gpu_info_thread)
        thread.daemon = True
        thread.start()
        
    def _get_gpu_info_thread(self):
        """Get GPU info from remote server"""
        try:
            # Execute nvidia-smi command
            stdin, stdout, stderr = self.ssh_client.exec_command('nvidia-smi --query-gpu=index,name,memory.total,memory.used,memory.free,utilization.gpu,temperature.gpu --format=csv,noheader,nounits')
            output = stdout.read().decode().strip()
            error = stderr.read().decode().strip()
            
            if error and "command not found" in error.lower():
                QTimer.singleShot(0, lambda: self.gpu_detection_failed("nvidia-smi not found on remote server"))
                return
            elif error:
                QTimer.singleShot(0, lambda: self.gpu_detection_failed(f"nvidia-smi error: {error}"))
                return
                
            if not output:
                QTimer.singleShot(0, lambda: self.gpu_detection_failed("No GPU output from nvidia-smi"))
                return
                
            # Parse GPU information
            gpu_info_list = []
            lines = output.strip().split('\n')
            
            for line in lines:
                if line.strip():
                    parts = [part.strip() for part in line.split(',')]
                    if len(parts) >= 7:
                        try:
                            gpu_info = {
                                'id': int(parts[0]),
                                'name': parts[1],
                                'memory_total': int(parts[2]),
                                'memory_used': int(parts[3]),
                                'memory_free': int(parts[4]),
                                'load': float(parts[5]),
                                'temperature': int(parts[6]) if parts[6] != '[Not Supported]' else 0
                            }
                            gpu_info_list.append(gpu_info)
                        except (ValueError, IndexError) as e:
                            continue
                            
            QTimer.singleShot(0, lambda: self.gpu_detection_success(gpu_info_list))
            
        except Exception as e:
            QTimer.singleShot(0, lambda: self.gpu_detection_failed(str(e)))
            
    def gpu_detection_success(self, gpu_info_list):
        """GPU detection successful"""
        # Clear loading message
        for i in reversed(range(self.gpu_layout.count())):
            self.gpu_layout.itemAt(i).widget().setParent(None)
            
        self.gpu_info = gpu_info_list
        
        if not gpu_info_list:
            no_gpu_label = QLabel("No CUDA GPUs detected on remote server")
            no_gpu_label.setStyleSheet("padding: 20px; text-align: center; color: gray; font-style: italic;")
            self.gpu_layout.addWidget(no_gpu_label)
            return
            
        for i, gpu_info in enumerate(gpu_info_list):
            gpu_card = self.create_gpu_card(gpu_info, i)
            self.gpu_layout.addWidget(gpu_card)
            
    def gpu_detection_failed(self, error):
        """GPU detection failed"""
        # Clear loading message
        for i in reversed(range(self.gpu_layout.count())):
            self.gpu_layout.itemAt(i).widget().setParent(None)
            
        error_label = QLabel(f"Failed to detect GPUs: {error}")
        error_label.setStyleSheet("padding: 20px; color: red; font-weight: bold;")
        self.gpu_layout.addWidget(error_label)
        
    def create_gpu_card(self, gpu_info, index):
        """Create GPU card"""
        card = QFrame()
        card.setFrameStyle(QFrame.Box)
        
        layout = QHBoxLayout()
        
        # GPU info
        info_layout = QVBoxLayout()
        
        name_label = QLabel(f"GPU {gpu_info['id']}: {gpu_info['name']}")
        name_label.setFont(QFont("Arial", 10, QFont.Bold))
        
        memory_label = QLabel(f"Memory: {gpu_info['memory_used']}/{gpu_info['memory_total']} MB")
        memory_usage = (gpu_info['memory_used'] / gpu_info['memory_total']) * 100 if gpu_info['memory_total'] > 0 else 0
        
        load_label = QLabel(f"Load: {gpu_info['load']:.1f}%")
        temp_label = QLabel(f"Temp: {gpu_info['temperature']}°C" if gpu_info['temperature'] > 0 else "Temp: N/A")
        
        # Color coding for high usage
        if memory_usage > 80:
            memory_label.setStyleSheet("color: red;")
        elif memory_usage > 50:
            memory_label.setStyleSheet("color: orange;")
        else:
            memory_label.setStyleSheet("color: green;")
            
        if gpu_info['load'] > 80:
            load_label.setStyleSheet("color: red;")
        elif gpu_info['load'] > 50:
            load_label.setStyleSheet("color: orange;")
        else:
            load_label.setStyleSheet("color: green;")
        
        info_layout.addWidget(name_label)
        info_layout.addWidget(memory_label)
        info_layout.addWidget(load_label)
        info_layout.addWidget(temp_label)
        
        # Select button
        select_btn = QPushButton("Select")
        select_btn.clicked.connect(lambda: self.select_gpu(gpu_info, index))
        
        layout.addLayout(info_layout)
        layout.addWidget(select_btn)
        
        card.setLayout(layout)
        return card
        
    def select_gpu(self, gpu_info, index):
        """Select GPU"""
        self.selected_gpu = gpu_info
        self.selection_label.setText(f"Selected: GPU {gpu_info['id']} - {gpu_info['name']}")
        self.selection_label.setStyleSheet("color: green; font-weight: bold;")

class TrainingUI(QMainWindow):
    """Main Training Interface"""
    
    def __init__(self):
        super().__init__()
        self.init_ui()
        
    def init_ui(self):
        self.setWindowTitle("Training UI")
        self.setGeometry(100, 100, 1000, 700)
        
        # Set simple style
        self.setStyleSheet("""
            QMainWindow {
                background-color: #f5f5f5;
            }
            QGroupBox {
                font-weight: bold;
                border: 1px solid #cccccc;
                margin-top: 10px;
                padding-top: 5px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 5px 0 5px;
            }
            QPushButton {
                padding: 5px 10px;
                border: 1px solid #cccccc;
                background-color: #ffffff;
            }
            QPushButton:hover {
                background-color: #e6e6e6;
            }
            QPushButton:pressed {
                background-color: #d4d4d4;
            }
            QLineEdit {
                padding: 5px;
                border: 1px solid #cccccc;
            }
            QTextEdit {
                border: 1px solid #cccccc;
            }
        """)
        
        # Create central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Create main layout
        main_layout = QHBoxLayout()
        
        # Left panel
        left_panel = self.create_left_panel()
        
        # Right panel
        self.right_panel = QStackedWidget()
        
        # Create module pages
        self.server_widget = ServerConnectionWidget()
        self.file_widget = FileTransferWidget()
        self.gpu_widget = GPUSelectionWidget()
        
        self.right_panel.addWidget(self.server_widget)
        self.right_panel.addWidget(self.file_widget)
        self.right_panel.addWidget(self.gpu_widget)
        
        # Set layout proportions
        main_layout.addWidget(left_panel, 1)
        main_layout.addWidget(self.right_panel, 3)
        
        central_widget.setLayout(main_layout)
        
        # Create status bar
        self.create_status_bar()
        
        # Connect signals
        self.server_widget.connection_status_changed.connect(self.update_connection_status)
        self.server_widget.ssh_client_changed.connect(self.gpu_widget.set_ssh_client)
        self.server_widget.ssh_client_changed.connect(self.file_widget.set_ssh_client)
        
    def create_left_panel(self):
        """Create left panel"""
        panel = QWidget()
        panel.setMaximumWidth(200)
        panel.setStyleSheet("background: white;")
        
        layout = QVBoxLayout()
        
        # Title
        title = QLabel("Modules")
        title.setFont(QFont("Arial", 16, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)
        
        # Module buttons
        self.module_buttons = []
        
        modules = [
            ("Server", 0),
            ("File Transfer", 1),
            ("GPU Selection", 2),
            ("Config", 3),
            ("Training", 4),
            ("Testing", 5)
        ]
        
        for name, index in modules:
            btn = QPushButton(name)
            btn.setStyleSheet("""
                QPushButton {
                    text-align: left;
                    padding: 10px;
                    margin: 2px;
                    border: 1px solid #cccccc;
                    background: white;
                }
                QPushButton:hover {
                    background: #f0f0f0;
                }
                QPushButton:checked {
                    background: #e0e0e0;
                    border: 2px solid #999999;
                }
            """)
            btn.setCheckable(True)
            
            if index < 3:  # Only first three modules are clickable
                btn.clicked.connect(lambda checked, idx=index: self.switch_module(idx))
            else:
                btn.setEnabled(False)
            
            self.module_buttons.append(btn)
            layout.addWidget(btn)
            
        # Set first button as checked
        self.module_buttons[0].setChecked(True)
            
        layout.addStretch()
        
        panel.setLayout(layout)
        return panel
        
    def switch_module(self, index):
        """Switch module"""
        self.right_panel.setCurrentIndex(index)
        
        # Update button states
        for i, btn in enumerate(self.module_buttons[:3]):
            btn.setChecked(i == index)
                
    def create_status_bar(self):
        """Create status bar"""
        self.status_bar = self.statusBar()
        
        # Connection status
        self.connection_status = QLabel("Not Connected")
        self.status_bar.addWidget(QLabel("Server:"))
        self.status_bar.addWidget(self.connection_status)
        
        self.status_bar.addPermanentWidget(QLabel("Ready"))
        
    def update_connection_status(self, connected, info):
        """Update connection status"""
        if connected:
            self.connection_status.setText(f"Connected: {info}")
        else:
            self.connection_status.setText("Not Connected")

def main():
    app = QApplication(sys.argv)
    
    # Set application style
    app.setStyle('Fusion')
    
    # Create main window
    window = TrainingUI()
    window.show()
    
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
