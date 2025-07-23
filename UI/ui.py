import sys
import os
import threading
import time
import paramiko
import GPUtil
from PyQt5.QtWidgets import *
from PyQt5.QtCore import *
from PyQt5.QtGui import *

class ServerConnectionWidget(QWidget):
    """Server Connection Module"""
    connection_status_changed = pyqtSignal(bool, str)
    
    def __init__(self):
        super().__init__()
        self.ssh_client = None
        self.sftp_client = None
        self.init_ui()
        
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setSpacing(10)
        layout.setContentsMargins(20, 20, 20, 20)
        
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
        
        form_layout.addRow("IP Address:", self.ip_input)
        form_layout.addRow("Username:", self.username_input)
        form_layout.addRow("Password:", self.password_input)
        
        layout.addLayout(form_layout)
        
        # Connect button
        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self.connect_to_server)
        layout.addWidget(self.connect_btn)
        
        # Status display
        self.status_label = QLabel("Status: Not Connected")
        layout.addWidget(self.status_label)
        
        # Info display
        self.info_text = QTextEdit()
        self.info_text.setMaximumHeight(80)
        self.info_text.setReadOnly(True)
        layout.addWidget(self.info_text)
        
        layout.addStretch()
        self.setLayout(layout)
        
    def connect_to_server(self):
        """Connect to server"""
        ip = self.ip_input.text().strip()
        username = self.username_input.text().strip()
        password = self.password_input.text().strip()
        
        if not all([ip, username, password]):
            self.show_error("Please fill in all fields")
            return
            
        self.connect_btn.setEnabled(False)
        self.connect_btn.setText("Connecting...")
        
        # Connect in new thread
        thread = threading.Thread(target=self._connect_thread, args=(ip, username, password))
        thread.daemon = True
        thread.start()
        
    def _connect_thread(self, ip, username, password):
        """Connection thread"""
        try:
            self.ssh_client = paramiko.SSHClient()
            self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.ssh_client.connect(ip, username=username, password=password, timeout=10)
            
            self.sftp_client = self.ssh_client.open_sftp()
            
            QTimer.singleShot(0, lambda: self.connection_success(ip, username))
            
        except Exception as e:
            QTimer.singleShot(0, lambda: self.connection_failed(str(e)))
            
    def connection_success(self, ip, username):
        """Connection successful"""
        self.status_label.setText("Status: Connected")
        self.info_text.append(f"Connected to {ip} as {username}")
        self.connect_btn.setText("Disconnect")
        self.connect_btn.setEnabled(True)
        self.connection_status_changed.emit(True, f"{ip}:{username}")
        
    def connection_failed(self, error):
        """Connection failed"""
        self.show_error(f"Connection failed: {error}")
        self.connect_btn.setText("Connect")
        self.connect_btn.setEnabled(True)
        
    def show_error(self, message):
        """Show error message"""
        self.status_label.setText(f"Status: {message}")
        self.info_text.append(f"Error: {message}")

class FileTransferWidget(QWidget):
    """File Transfer Module"""
    
    def __init__(self):
        super().__init__()
        self.local_path = ""
        self.remote_path = "/tmp/"
        self.init_ui()
        
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setSpacing(10)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Title
        title = QLabel("File Transfer")
        title.setFont(QFont("Arial", 14, QFont.Bold))
        layout.addWidget(title)
        
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
        
    def select_local_folder(self):
        """Select local folder"""
        folder = QFileDialog.getExistingDirectory(self, "Select Dataset Folder")
        if folder:
            self.local_path = folder
            self.local_path_label.setText(f"Selected: {os.path.basename(folder)}")
            self.upload_btn.setEnabled(True)
            
    def upload_dataset(self):
        """Upload dataset"""
        if not self.local_path:
            QMessageBox.warning(self, "Warning", "Please select a dataset folder first")
            return
            
        self.upload_btn.setEnabled(False)
        self.progress_bar.setVisible(True)
        self.upload_status.setText("Preparing upload...")
        
        # Simulate upload process
        self.simulate_upload()
        
    def simulate_upload(self):
        """Simulate upload process"""
        def update_progress():
            for i in range(101):
                time.sleep(0.03)
                QTimer.singleShot(0, lambda val=i: self.update_upload_progress(val))
                
        thread = threading.Thread(target=update_progress)
        thread.daemon = True
        thread.start()
        
    def update_upload_progress(self, value):
        """Update upload progress"""
        self.progress_bar.setValue(value)
        if value < 30:
            self.upload_status.setText("Compressing files...")
        elif value < 80:
            self.upload_status.setText("Uploading via SFTP...")
        elif value < 95:
            self.upload_status.setText("Extracting on server...")
        else:
            self.upload_status.setText("Upload completed")
            
        if value >= 100:
            self.upload_btn.setEnabled(True)
            QTimer.singleShot(2000, lambda: self.progress_bar.setVisible(False))

class GPUSelectionWidget(QWidget):
    """GPU Selection Module"""
    
    def __init__(self):
        super().__init__()
        self.selected_gpu = None
        self.gpu_info = []
        self.init_ui()
        self.refresh_gpu_info()
        
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setSpacing(10)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Title
        title = QLabel("GPU Selection")
        title.setFont(QFont("Arial", 14, QFont.Bold))
        layout.addWidget(title)
        
        # Refresh button
        refresh_btn = QPushButton("Refresh")
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
        
    def refresh_gpu_info(self):
        """Refresh GPU information"""
        try:
            gpus = GPUtil.getGPUs()
            self.gpu_info = []
            
            # Clear existing GPU cards
            for i in reversed(range(self.gpu_layout.count())):
                self.gpu_layout.itemAt(i).widget().setParent(None)
                
            if not gpus:
                no_gpu_label = QLabel("No CUDA GPUs detected")
                self.gpu_layout.addWidget(no_gpu_label)
                return
                
            for i, gpu in enumerate(gpus):
                gpu_info = {
                    'id': gpu.id,
                    'name': gpu.name,
                    'memory_total': gpu.memoryTotal,
                    'memory_used': gpu.memoryUsed,
                    'memory_free': gpu.memoryFree,
                    'load': gpu.load * 100,
                    'temperature': gpu.temperature
                }
                self.gpu_info.append(gpu_info)
                
                # Create GPU card
                gpu_card = self.create_gpu_card(gpu_info, i)
                self.gpu_layout.addWidget(gpu_card)
                
        except Exception as e:
            error_label = QLabel(f"Error detecting GPUs: {str(e)}")
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
        
        memory_label = QLabel(f"Memory: {gpu_info['memory_used']:.0f}/{gpu_info['memory_total']:.0f} MB")
        load_label = QLabel(f"Load: {gpu_info['load']:.1f}%")
        temp_label = QLabel(f"Temp: {gpu_info['temperature']}°C")
        
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
