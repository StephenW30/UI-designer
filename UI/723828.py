import sys
import os
import tarfile
import tempfile
import threading
from PyQt5.QtWidgets import *
from PyQt5.QtCore import *
from PyQt5.QtGui import *

try:
    import paramiko
    PARAMIKO_AVAILABLE = True
except ImportError:
    PARAMIKO_AVAILABLE = False
    print("Warning: paramiko not installed. Run: pip install paramiko")

class SSHConnectionThread(QThread):
    """SSH Connection Thread"""
    connection_result = pyqtSignal(bool, str, object)  # success, message, ssh_client
    
    def __init__(self, host, username, password, port=22):
        super().__init__()
        self.host = host
        self.username = username
        self.password = password
        self.port = port
        
    def run(self):
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(self.host, port=self.port, username=self.username, password=self.password, timeout=10)
            
            # Test connection
            stdin, stdout, stderr = ssh.exec_command('whoami')
            result = stdout.read().decode().strip()
            
            self.connection_result.emit(True, f"Connected as {result}", ssh)
        except Exception as e:
            self.connection_result.emit(False, str(e), None)

class GPUInfoThread(QThread):
    """GPU Information Thread"""
    gpu_info_result = pyqtSignal(bool, str, list)  # success, message, gpu_list
    
    def __init__(self, ssh_client):
        super().__init__()
        self.ssh_client = ssh_client
        
    def run(self):
        try:
            cmd = "nvidia-smi --query-gpu=index,name,memory.total,memory.used,utilization.gpu,temperature.gpu --format=csv,noheader,nounits"
            stdin, stdout, stderr = self.ssh_client.exec_command(cmd)
            output = stdout.read().decode().strip()
            error = stderr.read().decode().strip()
            
            if error:
                self.gpu_info_result.emit(False, f"nvidia-smi error: {error}", [])
                return
                
            if not output:
                self.gpu_info_result.emit(False, "No GPU output", [])
                return
                
            gpu_list = []
            for line in output.split('\n'):
                if line.strip():
                    parts = [p.strip() for p in line.split(',')]
                    if len(parts) >= 6:
                        try:
                            gpu_info = {
                                'index': int(parts[0]),
                                'name': parts[1],
                                'memory_total': int(parts[2]),
                                'memory_used': int(parts[3]),
                                'utilization': float(parts[4]),
                                'temperature': int(parts[5]) if parts[5] != '[Not Supported]' else 0
                            }
                            gpu_list.append(gpu_info)
                        except (ValueError, IndexError):
                            continue
                            
            self.gpu_info_result.emit(True, f"Found {len(gpu_list)} GPUs", gpu_list)
            
        except Exception as e:
            self.gpu_info_result.emit(False, str(e), [])

class FileUploadThread(QThread):
    """File Upload Thread"""
    upload_progress = pyqtSignal(int, str)  # progress, message
    upload_result = pyqtSignal(bool, str)  # success, message
    
    def __init__(self, ssh_client, local_folder, remote_folder):
        super().__init__()
        self.ssh_client = ssh_client
        self.local_folder = local_folder
        self.remote_folder = remote_folder
        
    def run(self):
        try:
            # Create tar file
            self.upload_progress.emit(10, "Creating tar archive...")
            temp_tar = tempfile.mktemp(suffix='.tar')
            
            with tarfile.open(temp_tar, 'w') as tar:
                tar.add(self.local_folder, arcname=os.path.basename(self.local_folder))
                
            self.upload_progress.emit(30, "Archive created, uploading...")
            
            # Upload file
            sftp = self.ssh_client.open_sftp()
            remote_tar = f"{self.remote_folder}/{os.path.basename(self.local_folder)}.tar"
            
            def progress_callback(transferred, total):
                progress = int(30 + (transferred / total) * 50)
                self.upload_progress.emit(progress, f"Uploading... {transferred}/{total} bytes")
            
            sftp.put(temp_tar, remote_tar, callback=progress_callback)
            sftp.close()
            
            self.upload_progress.emit(80, "Extracting on remote server...")
            
            # Extract and cleanup on remote
            extract_cmd = f"cd {self.remote_folder} && tar -xf {os.path.basename(remote_tar)} && rm {os.path.basename(remote_tar)}"
            stdin, stdout, stderr = self.ssh_client.exec_command(extract_cmd)
            exit_status = stdout.channel.recv_exit_status()
            
            # Remove local tar file
            os.remove(temp_tar)
            
            if exit_status == 0:
                self.upload_progress.emit(100, "Upload completed successfully")
                self.upload_result.emit(True, "Upload completed")
            else:
                error = stderr.read().decode().strip()
                self.upload_result.emit(False, f"Extract failed: {error}")
                
        except Exception as e:
            # Cleanup on error
            try:
                if 'temp_tar' in locals():
                    os.remove(temp_tar)
            except:
                pass
            self.upload_result.emit(False, str(e))

class ServerConnectionWidget(QWidget):
    """Server Connection Module"""
    connection_changed = pyqtSignal(bool, object)  # connected, ssh_client
    
    def __init__(self):
        super().__init__()
        self.ssh_client = None
        self.connection_thread = None
        self.init_ui()
        
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)
        
        # Title
        title = QLabel("Server Connection")
        title.setFont(QFont("Arial", 16, QFont.Bold))
        layout.addWidget(title)
        
        if not PARAMIKO_AVAILABLE:
            error_label = QLabel("Error: paramiko not installed\nRun: pip install paramiko")
            error_label.setStyleSheet("color: red; font-weight: bold; padding: 10px; border: 1px solid red;")
            layout.addWidget(error_label)
            self.setLayout(layout)
            return
        
        # Connection form
        form_widget = QWidget()
        form_layout = QFormLayout()
        
        self.host_input = QLineEdit()
        self.host_input.setPlaceholderText("192.168.1.100")
        
        self.username_input = QLineEdit()
        self.username_input.setPlaceholderText("username")
        
        self.password_input = QLineEdit()
        self.password_input.setEchoMode(QLineEdit.Password)
        self.password_input.setPlaceholderText("password")
        
        self.port_input = QLineEdit("22")
        
        form_layout.addRow("Host:", self.host_input)
        form_layout.addRow("Username:", self.username_input)
        form_layout.addRow("Password:", self.password_input)
        form_layout.addRow("Port:", self.port_input)
        
        form_widget.setLayout(form_layout)
        layout.addWidget(form_widget)
        
        # Connect button
        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self.toggle_connection)
        layout.addWidget(self.connect_btn)
        
        # Status
        self.status_label = QLabel("Not Connected")
        self.status_label.setStyleSheet("padding: 8px; border: 1px solid #ccc; background: #f9f9f9;")
        layout.addWidget(self.status_label)
        
        # Connection info
        self.info_text = QTextEdit()
        self.info_text.setMaximumHeight(100)
        self.info_text.setReadOnly(True)
        layout.addWidget(self.info_text)
        
        layout.addStretch()
        self.setLayout(layout)
        
    def toggle_connection(self):
        if self.ssh_client:
            self.disconnect()
        else:
            self.connect()
            
    def connect(self):
        host = self.host_input.text().strip()
        username = self.username_input.text().strip()
        password = self.password_input.text().strip()
        port = int(self.port_input.text().strip()) if self.port_input.text().strip() else 22
        
        if not all([host, username, password]):
            QMessageBox.warning(self, "Warning", "Please fill in all fields")
            return
            
        self.connect_btn.setEnabled(False)
        self.connect_btn.setText("Connecting...")
        self.status_label.setText("Connecting...")
        self.info_text.append(f"Connecting to {host}:{port}...")
        
        self.connection_thread = SSHConnectionThread(host, username, password, port)
        self.connection_thread.connection_result.connect(self.on_connection_result)
        self.connection_thread.start()
        
    def disconnect(self):
        if self.ssh_client:
            try:
                self.ssh_client.close()
            except:
                pass
            self.ssh_client = None
            
        self.status_label.setText("Not Connected")
        self.connect_btn.setText("Connect")
        self.connect_btn.setEnabled(True)
        self.info_text.append("Disconnected")
        self.connection_changed.emit(False, None)
        
    def on_connection_result(self, success, message, ssh_client):
        if success:
            self.ssh_client = ssh_client
            self.status_label.setText("Connected")
            self.status_label.setStyleSheet("padding: 8px; border: 1px solid green; background: #f0fff0;")
            self.connect_btn.setText("Disconnect")
            self.info_text.append(f"Success: {message}")
            self.connection_changed.emit(True, ssh_client)
        else:
            self.status_label.setText("Connection Failed")
            self.status_label.setStyleSheet("padding: 8px; border: 1px solid red; background: #fff0f0;")
            self.info_text.append(f"Error: {message}")
            
        self.connect_btn.setEnabled(True)

class FileTransferWidget(QWidget):
    """File Transfer Module"""
    
    def __init__(self):
        super().__init__()
        self.ssh_client = None
        self.local_folder = ""
        self.upload_thread = None
        self.init_ui()
        
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)
        
        # Title
        title = QLabel("File Transfer")
        title.setFont(QFont("Arial", 16, QFont.Bold))
        layout.addWidget(title)
        
        # Connection status
        self.conn_status = QLabel("No SSH connection")
        self.conn_status.setStyleSheet("padding: 8px; border: 1px solid orange; background: #fff8dc;")
        layout.addWidget(self.conn_status)
        
        # Local folder selection
        local_group = QGroupBox("Local Folder")
        local_layout = QVBoxLayout()
        
        self.folder_label = QLabel("No folder selected")
        self.folder_label.setStyleSheet("padding: 8px; border: 1px solid #ccc; background: white;")
        
        self.select_btn = QPushButton("Select Folder")
        self.select_btn.clicked.connect(self.select_folder)
        
        local_layout.addWidget(self.folder_label)
        local_layout.addWidget(self.select_btn)
        local_group.setLayout(local_layout)
        layout.addWidget(local_group)
        
        # Remote folder
        remote_group = QGroupBox("Remote Folder")
        remote_layout = QVBoxLayout()
        
        self.remote_input = QLineEdit("/tmp")
        remote_layout.addWidget(self.remote_input)
        remote_group.setLayout(remote_layout)
        layout.addWidget(remote_group)
        
        # Upload
        upload_group = QGroupBox("Upload")
        upload_layout = QVBoxLayout()
        
        self.upload_btn = QPushButton("Upload Folder")
        self.upload_btn.clicked.connect(self.upload_folder)
        self.upload_btn.setEnabled(False)
        
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        
        self.progress_label = QLabel("")
        
        upload_layout.addWidget(self.upload_btn)
        upload_layout.addWidget(self.progress_bar)
        upload_layout.addWidget(self.progress_label)
        upload_group.setLayout(upload_layout)
        layout.addWidget(upload_group)
        
        layout.addStretch()
        self.setLayout(layout)
        
    def set_ssh_client(self, ssh_client):
        self.ssh_client = ssh_client
        if ssh_client:
            self.conn_status.setText("SSH connected")
            self.conn_status.setStyleSheet("padding: 8px; border: 1px solid green; background: #f0fff0;")
            self.update_upload_button()
        else:
            self.conn_status.setText("No SSH connection")
            self.conn_status.setStyleSheet("padding: 8px; border: 1px solid orange; background: #fff8dc;")
            self.upload_btn.setEnabled(False)
            
    def select_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Select Dataset Folder")
        if folder:
            self.local_folder = folder
            self.folder_label.setText(f"Selected: {os.path.basename(folder)}")
            self.update_upload_button()
            
    def update_upload_button(self):
        self.upload_btn.setEnabled(bool(self.ssh_client and self.local_folder))
        
    def upload_folder(self):
        if not self.ssh_client or not self.local_folder:
            return
            
        remote_folder = self.remote_input.text().strip()
        if not remote_folder:
            QMessageBox.warning(self, "Warning", "Please specify remote folder")
            return
            
        self.upload_btn.setEnabled(False)
        self.progress_bar.setVisible(True)
        self.progress_bar.setValue(0)
        
        self.upload_thread = FileUploadThread(self.ssh_client, self.local_folder, remote_folder)
        self.upload_thread.upload_progress.connect(self.on_upload_progress)
        self.upload_thread.upload_result.connect(self.on_upload_result)
        self.upload_thread.start()
        
    def on_upload_progress(self, progress, message):
        self.progress_bar.setValue(progress)
        self.progress_label.setText(message)
        
    def on_upload_result(self, success, message):
        if success:
            self.progress_label.setText("Upload completed successfully")
            QTimer.singleShot(3000, lambda: self.progress_bar.setVisible(False))
        else:
            self.progress_label.setText(f"Upload failed: {message}")
            
        self.upload_btn.setEnabled(True)

class GPUSelectionWidget(QWidget):
    """GPU Selection Module"""
    gpu_selected = pyqtSignal(int, str)  # gpu_index, gpu_name
    
    def __init__(self):
        super().__init__()
        self.ssh_client = None
        self.gpu_list = []
        self.selected_gpu_index = None
        self.gpu_thread = None
        self.init_ui()
        
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)
        
        # Title
        title = QLabel("GPU Selection")
        title.setFont(QFont("Arial", 16, QFont.Bold))
        layout.addWidget(title)
        
        # Connection status
        self.conn_status = QLabel("No SSH connection")
        self.conn_status.setStyleSheet("padding: 8px; border: 1px solid orange; background: #fff8dc;")
        layout.addWidget(self.conn_status)
        
        # Refresh button
        self.refresh_btn = QPushButton("Refresh GPU Info")
        self.refresh_btn.clicked.connect(self.refresh_gpu_info)
        self.refresh_btn.setEnabled(False)
        layout.addWidget(self.refresh_btn)
        
        # GPU list
        self.gpu_scroll = QScrollArea()
        self.gpu_widget = QWidget()
        self.gpu_layout = QVBoxLayout()
        self.gpu_widget.setLayout(self.gpu_layout)
        self.gpu_scroll.setWidget(self.gpu_widget)
        self.gpu_scroll.setWidgetResizable(True)
        layout.addWidget(self.gpu_scroll)
        
        # Selection status
        self.selection_label = QLabel("No GPU selected")
        self.selection_label.setStyleSheet("padding: 8px; border: 1px solid #ccc; background: #f9f9f9; font-weight: bold;")
        layout.addWidget(self.selection_label)
        
        layout.addStretch()
        self.setLayout(layout)
        
        self.show_no_connection()
        
    def set_ssh_client(self, ssh_client):
        self.ssh_client = ssh_client
        if ssh_client:
            self.conn_status.setText("SSH connected")
            self.conn_status.setStyleSheet("padding: 8px; border: 1px solid green; background: #f0fff0;")
            self.refresh_btn.setEnabled(True)
            self.refresh_gpu_info()
        else:
            self.conn_status.setText("No SSH connection")
            self.conn_status.setStyleSheet("padding: 8px; border: 1px solid orange; background: #fff8dc;")
            self.refresh_btn.setEnabled(False)
            self.show_no_connection()
            
    def show_no_connection(self):
        self.clear_gpu_list()
        no_conn_label = QLabel("Please connect to SSH server first")
        no_conn_label.setStyleSheet("padding: 20px; text-align: center; color: gray;")
        no_conn_label.setAlignment(Qt.AlignCenter)
        self.gpu_layout.addWidget(no_conn_label)
        
    def clear_gpu_list(self):
        for i in reversed(range(self.gpu_layout.count())):
            child = self.gpu_layout.itemAt(i).widget()
            if child:
                child.setParent(None)
                
    def refresh_gpu_info(self):
        if not self.ssh_client:
            return
            
        self.clear_gpu_list()
        loading_label = QLabel("Loading GPU information...")
        loading_label.setAlignment(Qt.AlignCenter)
        self.gpu_layout.addWidget(loading_label)
        
        self.refresh_btn.setEnabled(False)
        self.refresh_btn.setText("Loading...")
        
        self.gpu_thread = GPUInfoThread(self.ssh_client)
        self.gpu_thread.gpu_info_result.connect(self.on_gpu_info_result)
        self.gpu_thread.start()
        
    def on_gpu_info_result(self, success, message, gpu_list):
        self.clear_gpu_list()
        
        if success and gpu_list:
            self.gpu_list = gpu_list
            for gpu in gpu_list:
                gpu_card = self.create_gpu_card(gpu)
                self.gpu_layout.addWidget(gpu_card)
        else:
            error_label = QLabel(f"Failed to get GPU info: {message}")
            error_label.setStyleSheet("padding: 20px; color: red; text-align: center;")
            error_label.setAlignment(Qt.AlignCenter)
            self.gpu_layout.addWidget(error_label)
            
        self.refresh_btn.setEnabled(True)
        self.refresh_btn.setText("Refresh GPU Info")
        
    def create_gpu_card(self, gpu):
        card = QFrame()
        card.setFrameStyle(QFrame.Box)
        card.setStyleSheet("QFrame { border: 1px solid #ccc; margin: 2px; padding: 5px; }")
        
        layout = QHBoxLayout()
        
        # GPU info
        info_layout = QVBoxLayout()
        
        name_label = QLabel(f"GPU {gpu['index']}: {gpu['name']}")
        name_label.setFont(QFont("Arial", 11, QFont.Bold))
        
        memory_label = QLabel(f"Memory: {gpu['memory_used']}/{gpu['memory_total']} MB")
        utilization_label = QLabel(f"Utilization: {gpu['utilization']:.1f}%")
        temp_label = QLabel(f"Temperature: {gpu['temperature']}°C" if gpu['temperature'] > 0 else "Temperature: N/A")
        
        # Color coding
        memory_percent = (gpu['memory_used'] / gpu['memory_total']) * 100
        if memory_percent > 80:
            memory_label.setStyleSheet("color: red;")
        elif memory_percent > 50:
            memory_label.setStyleSheet("color: orange;")
        else:
            memory_label.setStyleSheet("color: green;")
            
        if gpu['utilization'] > 80:
            utilization_label.setStyleSheet("color: red;")
        elif gpu['utilization'] > 50:
            utilization_label.setStyleSheet("color: orange;")
        else:
            utilization_label.setStyleSheet("color: green;")
        
        info_layout.addWidget(name_label)
        info_layout.addWidget(memory_label)
        info_layout.addWidget(utilization_label)
        info_layout.addWidget(temp_label)
        
        # Select button
        select_btn = QPushButton("Select")
        select_btn.clicked.connect(lambda: self.select_gpu(gpu))
        
        layout.addLayout(info_layout)
        layout.addWidget(select_btn)
        card.setLayout(layout)
        
        return card
        
    def select_gpu(self, gpu):
        self.selected_gpu_index = gpu['index']
        self.selection_label.setText(f"Selected: GPU {gpu['index']} - {gpu['name']}")
        self.selection_label.setStyleSheet("padding: 8px; border: 1px solid green; background: #f0fff0; font-weight: bold;")
        self.gpu_selected.emit(gpu['index'], gpu['name'])

class TrainingUI(QMainWindow):
    """Main Training UI"""
    
    def __init__(self):
        super().__init__()
        self.init_ui()
        self.setup_connections()
        
    def init_ui(self):
        self.setWindowTitle("Training UI")
        self.setGeometry(100, 100, 1000, 700)
        
        # Set style
        self.setStyleSheet("""
            QMainWindow {
                background-color: #f5f5f5;
            }
            QGroupBox {
                font-weight: bold;
                border: 1px solid #ccc;
                border-radius: 5px;
                margin-top: 10px;
                padding-top: 5px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 5px 0 5px;
            }
            QPushButton {
                padding: 8px 15px;
                border: 1px solid #ccc;
                border-radius: 3px;
                background-color: white;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #e6e6e6;
            }
            QPushButton:pressed {
                background-color: #d4d4d4;
            }
            QPushButton:disabled {
                background-color: #f0f0f0;
                color: #999;
            }
            QLineEdit {
                padding: 8px;
                border: 1px solid #ccc;
                border-radius: 3px;
            }
            QTextEdit {
                border: 1px solid #ccc;
                border-radius: 3px;
            }
        """)
        
        # Create central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Main layout
        main_layout = QHBoxLayout()
        main_layout.setSpacing(0)
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        # Left sidebar
        sidebar = self.create_sidebar()
        main_layout.addWidget(sidebar)
        
        # Right content area
        self.content_stack = QStackedWidget()
        self.content_stack.setStyleSheet("background: white; border-left: 1px solid #ccc;")
        
        # Create content widgets
        self.server_widget = ServerConnectionWidget()
        self.file_widget = FileTransferWidget()
        self.gpu_widget = GPUSelectionWidget()
        
        self.content_stack.addWidget(self.server_widget)
        self.content_stack.addWidget(self.file_widget)
        self.content_stack.addWidget(self.gpu_widget)
        
        main_layout.addWidget(self.content_stack)
        
        # Set proportions
        main_layout.setStretch(0, 0)  # Sidebar fixed width
        main_layout.setStretch(1, 1)  # Content area flexible
        
        central_widget.setLayout(main_layout)
        
        # Status bar
        self.status_bar = self.statusBar()
        self.connection_status = QLabel("Not Connected")
        self.status_bar.addWidget(QLabel("Server:"))
        self.status_bar.addWidget(self.connection_status)
        
    def create_sidebar(self):
        sidebar = QWidget()
        sidebar.setFixedWidth(200)
        sidebar.setStyleSheet("background: #2c3e50; color: white;")
        
        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        # Title
        title = QLabel("Training UI")
        title.setFont(QFont("Arial", 16, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("padding: 20px; background: #34495e; color: white;")
        layout.addWidget(title)
        
        # Menu buttons
        self.menu_buttons = []
        
        modules = [
            ("Server Connection", 0),
            ("File Transfer", 1),
            ("GPU Selection", 2),
            ("Configuration", 3),
            ("Training", 4),
            ("Testing", 5)
        ]
        
        button_style = """
            QPushButton {
                text-align: left;
                padding: 15px 20px;
                border: none;
                background: transparent;
                color: white;
                font-size: 14px;
                font-weight: normal;
            }
            QPushButton:hover {
                background: #34495e;
            }
            QPushButton:checked {
                background: #3498db;
            }
        """
        
        for name, index in modules:
            btn = QPushButton(name)
            btn.setStyleSheet(button_style)
            btn.setCheckable(True)
            
            if index < 3:  # Only first 3 modules are functional
                btn.clicked.connect(lambda checked, idx=index: self.switch_content(idx))
            else:
                btn.setEnabled(False)
                btn.setStyleSheet(button_style + "QPushButton:disabled { color: #7f8c8d; }")
            
            self.menu_buttons.append(btn)
            layout.addWidget(btn)
            
        # Set first button as checked
        self.menu_buttons[0].setChecked(True)
        
        layout.addStretch()
        sidebar.setLayout(layout)
        
        return sidebar
        
    def switch_content(self, index):
        self.content_stack.setCurrentIndex(index)
        
        # Update button states
        for i, btn in enumerate(self.menu_buttons[:3]):
            btn.setChecked(i == index)
            
    def setup_connections(self):
        # Connect server connection to other modules
        self.server_widget.connection_changed.connect(self.on_connection_changed)
        self.gpu_widget.gpu_selected.connect(self.on_gpu_selected)
        
    def on_connection_changed(self, connected, ssh_client):
        if connected:
            self.connection_status.setText("Connected")
            self.connection_status.setStyleSheet("color: green;")
            self.file_widget.set_ssh_client(ssh_client)
            self.gpu_widget.set_ssh_client(ssh_client)
        else:
            self.connection_status.setText("Not Connected")
            self.connection_status.setStyleSheet("color: red;")
            self.file_widget.set_ssh_client(None)
            self.gpu_widget.set_ssh_client(None)
            
    def on_gpu_selected(self, gpu_index, gpu_name):
        self.status_bar.showMessage(f"Selected GPU {gpu_index}: {gpu_name}", 5000)

def main():
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    
    window = TrainingUI()
    window.show()
    
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
