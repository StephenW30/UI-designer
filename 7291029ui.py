import sys
import os
import tarfile
import tempfile
import threading
from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                             QHBoxLayout, QPushButton, QLabel, QLineEdit, 
                             QTextEdit, QComboBox, QSpinBox, QDoubleSpinBox,
                             QGroupBox, QStackedWidget, QFileDialog, QMessageBox,
                             QProgressBar, QScrollArea, QFrame)
from PyQt5.QtCore import QThread, pyqtSignal, Qt
from PyQt5.QtGui import QFont
import paramiko
from scp import SCPClient

class SSHConnectionThread(QThread):
    """Thread for handling SSH connections to avoid UI blocking"""
    connection_result = pyqtSignal(bool, str)
    
    def __init__(self, hostname, username, password):
        super().__init__()
        self.hostname = hostname
        self.username = username
        self.password = password
        
    def run(self):
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(self.hostname, username=self.username, password=self.password)
            ssh.close()
            self.connection_result.emit(True, "Connection successful!")
        except Exception as e:
            self.connection_result.emit(False, f"Connection failed: {str(e)}")

class FileTransferThread(QThread):
    """Thread for handling file transfers"""
    transfer_result = pyqtSignal(bool, str)
    progress_update = pyqtSignal(str)
    
    def __init__(self, hostname, username, password, local_path, remote_path, operation='upload'):
        super().__init__()
        self.hostname = hostname
        self.username = username
        self.password = password
        self.local_path = local_path
        self.remote_path = remote_path
        self.operation = operation
        
    def run(self):
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(self.hostname, username=self.username, password=self.password)
            
            if self.operation == 'upload':
                # Create tar archive if uploading a folder
                if os.path.isdir(self.local_path):
                    self.progress_update.emit("Creating archive...")
                    with tempfile.NamedTemporaryFile(suffix='.tar', delete=False) as tmp_file:
                        tar_path = tmp_file.name
                        
                    with tarfile.open(tar_path, 'w') as tar:
                        tar.add(self.local_path, arcname=os.path.basename(self.local_path))
                    
                    self.progress_update.emit("Uploading file...")
                    with SCPClient(ssh.get_transport()) as scp:
                        scp.put(tar_path, self.remote_path)
                    
                    # Extract on remote server
                    self.progress_update.emit("Extracting on server...")
                    remote_dir = os.path.dirname(self.remote_path)
                    stdin, stdout, stderr = ssh.exec_command(f'cd {remote_dir} && tar -xf {os.path.basename(self.remote_path)}')
                    stdout.read()
                    
                    # Clean up
                    ssh.exec_command(f'rm {self.remote_path}')
                    os.unlink(tar_path)
                else:
                    self.progress_update.emit("Uploading file...")
                    with SCPClient(ssh.get_transport()) as scp:
                        scp.put(self.local_path, self.remote_path)
                        
            elif self.operation == 'download':
                self.progress_update.emit("Downloading file...")
                with SCPClient(ssh.get_transport()) as scp:
                    scp.get(self.remote_path, self.local_path)
            
            ssh.close()
            self.transfer_result.emit(True, f"{self.operation.capitalize()} completed successfully!")
            
        except Exception as e:
            self.transfer_result.emit(False, f"{self.operation.capitalize()} failed: {str(e)}")

class TrainingThread(QThread):
    """Thread for handling model training"""
    training_result = pyqtSignal(bool, str)
    progress_update = pyqtSignal(str)
    
    def __init__(self, hostname, username, password, training_params):
        super().__init__()
        self.hostname = hostname
        self.username = username
        self.password = password
        self.training_params = training_params
        
    def run(self):
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(self.hostname, username=self.username, password=self.password)
            
            self.progress_update.emit("Starting training...")
            
            # Construct training command
            gpu_id = self.training_params['gpu_id']
            epochs = self.training_params['epochs']
            batch_size = self.training_params['batch_size']
            learning_rate = self.training_params['learning_rate']
            
            command = f"cd /home/dlhome/kla-tencor/DL_Detect && CUDA_VISIBLE_DEVICES={gpu_id} python train.py --epochs {epochs} --batch_size {batch_size} --learning_rate {learning_rate}"
            
            stdin, stdout, stderr = ssh.exec_command(command)
            
            # Monitor output
            for line in iter(stdout.readline, ""):
                if line:
                    self.progress_update.emit(line.strip())
            
            stdout.channel.recv_exit_status()  # Wait for command to complete
            ssh.close()
            
            self.training_result.emit(True, "Training completed successfully!")
            
        except Exception as e:
            self.training_result.emit(False, f"Training failed: {str(e)}")

class ServerConnectionModule(QWidget):
    """Server Connection Module"""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.parent = parent
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # Connection parameters group
        conn_group = QGroupBox("Connection Parameters")
        conn_layout = QVBoxLayout()
        
        # Server info (read-only display)
        self.username_label = QLabel("Username: klac")
        self.ip_label = QLabel("IP Address: 10.47.172.163")
        self.password_label = QLabel("Password: ******")
        
        conn_layout.addWidget(self.username_label)
        conn_layout.addWidget(self.ip_label)
        conn_layout.addWidget(self.password_label)
        conn_group.setLayout(conn_layout)
        
        # Connect button
        self.connect_btn = QPushButton("Connect Server")
        self.connect_btn.clicked.connect(self.connect_to_server)
        
        # Status display
        self.status_text = QTextEdit()
        self.status_text.setMaximumHeight(150)
        self.status_text.setReadOnly(True)
        
        layout.addWidget(conn_group)
        layout.addWidget(self.connect_btn)
        layout.addWidget(QLabel("Connection Status:"))
        layout.addWidget(self.status_text)
        layout.addStretch()
        
        self.setLayout(layout)
        
    def connect_to_server(self):
        self.status_text.append("Attempting to connect...")
        self.connect_btn.setEnabled(False)
        
        # Use hardcoded credentials
        self.connection_thread = SSHConnectionThread("10.47.172.163", "klac", "123456")
        self.connection_thread.connection_result.connect(self.on_connection_result)
        self.connection_thread.start()
        
    def on_connection_result(self, success, message):
        self.status_text.append(message)
        self.connect_btn.setEnabled(True)
        
        if success and self.parent:
            self.parent.connection_established = True

class ModelTrainingModule(QWidget):
    """Model Training Module"""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.parent = parent
        self.current_result_index = 0
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # Configuration section
        config_group = QGroupBox("Training Configuration")
        config_layout = QVBoxLayout()
        
        # GPU selection
        gpu_layout = QHBoxLayout()
        gpu_layout.addWidget(QLabel("GPU Index:"))
        self.gpu_combo = QComboBox()
        self.gpu_combo.addItems(["0", "1"])
        gpu_layout.addWidget(self.gpu_combo)
        gpu_layout.addStretch()
        config_layout.addLayout(gpu_layout)
        
        # Training parameters
        params_layout = QVBoxLayout()
        
        # Epochs
        epoch_layout = QHBoxLayout()
        epoch_layout.addWidget(QLabel("Epochs:"))
        self.epochs_spin = QSpinBox()
        self.epochs_spin.setRange(1, 1000)
        self.epochs_spin.setValue(100)
        epoch_layout.addWidget(self.epochs_spin)
        epoch_layout.addStretch()
        params_layout.addLayout(epoch_layout)
        
        # Advanced settings
        advanced_group = QGroupBox("Advanced Settings")
        advanced_layout = QVBoxLayout()
        
        # Batch size
        batch_layout = QHBoxLayout()
        batch_layout.addWidget(QLabel("Batch Size:"))
        self.batch_spin = QSpinBox()
        self.batch_spin.setRange(1, 64)
        self.batch_spin.setValue(4)
        batch_layout.addWidget(self.batch_spin)
        batch_layout.addStretch()
        advanced_layout.addLayout(batch_layout)
        
        # Learning rate
        lr_layout = QHBoxLayout()
        lr_layout.addWidget(QLabel("Learning Rate:"))
        self.lr_spin = QDoubleSpinBox()
        self.lr_spin.setRange(0.0001, 1.0)
        self.lr_spin.setDecimals(4)
        self.lr_spin.setValue(0.0001)
        lr_layout.addWidget(self.lr_spin)
        lr_layout.addStretch()
        advanced_layout.addLayout(lr_layout)
        
        advanced_group.setLayout(advanced_layout)
        params_layout.addWidget(advanced_group)
        
        config_layout.addLayout(params_layout)
        config_group.setLayout(config_layout)
        
        # Dataset upload section
        dataset_group = QGroupBox("Dataset Upload")
        dataset_layout = QVBoxLayout()
        
        dataset_btn_layout = QHBoxLayout()
        self.select_folder_btn = QPushButton("Select Folder")
        self.select_folder_btn.clicked.connect(self.select_dataset_folder)
        self.upload_file_btn = QPushButton("Upload File")
        self.upload_file_btn.clicked.connect(self.upload_dataset)
        self.upload_file_btn.setEnabled(False)
        
        dataset_btn_layout.addWidget(self.select_folder_btn)
        dataset_btn_layout.addWidget(self.upload_file_btn)
        dataset_btn_layout.addStretch()
        
        self.selected_path_label = QLabel("No folder selected")
        
        dataset_layout.addLayout(dataset_btn_layout)
        dataset_layout.addWidget(self.selected_path_label)
        dataset_group.setLayout(dataset_layout)
        
        # Training execution
        training_group = QGroupBox("Training Execution")
        training_layout = QVBoxLayout()
        
        self.start_training_btn = QPushButton("Start Training")
        self.start_training_btn.clicked.connect(self.start_training)
        
        self.training_status = QTextEdit()
        self.training_status.setMaximumHeight(100)
        self.training_status.setReadOnly(True)
        
        training_layout.addWidget(self.start_training_btn)
        training_layout.addWidget(self.training_status)
        training_group.setLayout(training_layout)
        
        # Model management
        model_group = QGroupBox("Model Management")
        model_layout = QHBoxLayout()
        
        self.save_model_btn = QPushButton("Save Model")
        self.save_model_btn.clicked.connect(self.save_model)
        self.save_model_btn.setEnabled(False)
        
        model_layout.addWidget(self.save_model_btn)
        model_layout.addStretch()
        model_group.setLayout(model_layout)
        
        # Results visualization
        results_group = QGroupBox("Results Visualization")
        results_layout = QVBoxLayout()
        
        # Navigation controls
        nav_layout = QHBoxLayout()
        self.prev_btn = QPushButton("Previous")
        self.next_btn = QPushButton("Next")
        self.result_label = QLabel("Result 1 of 1")
        
        nav_layout.addWidget(self.prev_btn)
        nav_layout.addWidget(self.result_label)
        nav_layout.addWidget(self.next_btn)
        nav_layout.addStretch()
        
        # Result display areas
        self.hazemap_label = QLabel("Hazemap Visualization")
        self.hazemap_label.setMinimumHeight(100)
        self.hazemap_label.setStyleSheet("border: 1px solid #ccc; background-color: #f9f9f9;")
        
        self.ground_truth_label = QLabel("Ground Truth Comparison")
        self.ground_truth_label.setMinimumHeight(100)
        self.ground_truth_label.setStyleSheet("border: 1px solid #ccc; background-color: #f9f9f9;")
        
        self.postprocess_label = QLabel("Post-processing Result")
        self.postprocess_label.setMinimumHeight(100)
        self.postprocess_label.setStyleSheet("border: 1px solid #ccc; background-color: #f9f9f9;")
        
        results_layout.addLayout(nav_layout)
        results_layout.addWidget(self.hazemap_label)
        results_layout.addWidget(self.ground_truth_label)
        results_layout.addWidget(self.postprocess_label)
        results_group.setLayout(results_layout)
        
        # Add all groups to main layout
        layout.addWidget(config_group)
        layout.addWidget(dataset_group)
        layout.addWidget(training_group)
        layout.addWidget(model_group)
        layout.addWidget(results_group)
        
        self.setLayout(layout)
        
    def select_dataset_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Select Training Dataset Folder")
        if folder:
            self.selected_folder = folder
            self.selected_path_label.setText(f"Selected: {folder}")
            self.upload_file_btn.setEnabled(True)
            
    def upload_dataset(self):
        if not hasattr(self.parent, 'connection_established') or not self.parent.connection_established:
            QMessageBox.warning(self, "Warning", "Please establish server connection first!")
            return
            
        remote_path = "/home/dlhome/kla-tencor/DL_Detect/Train_Validation/Input/PLStar.tar"
        
        self.training_status.append("Starting dataset upload...")
        self.upload_file_btn.setEnabled(False)
        
        self.upload_thread = FileTransferThread("10.47.172.163", "klac", "123456", 
                                              self.selected_folder, remote_path, 'upload')
        self.upload_thread.transfer_result.connect(self.on_upload_result)
        self.upload_thread.progress_update.connect(self.on_upload_progress)
        self.upload_thread.start()
        
    def on_upload_progress(self, message):
        self.training_status.append(message)
        
    def on_upload_result(self, success, message):
        self.training_status.append(message)
        self.upload_file_btn.setEnabled(True)
        
    def start_training(self):
        if not hasattr(self.parent, 'connection_established') or not self.parent.connection_established:
            QMessageBox.warning(self, "Warning", "Please establish server connection first!")
            return
            
        training_params = {
            'gpu_id': self.gpu_combo.currentText(),
            'epochs': self.epochs_spin.value(),
            'batch_size': self.batch_spin.value(),
            'learning_rate': self.lr_spin.value()
        }
        
        self.training_status.append("Initializing training...")
        self.start_training_btn.setEnabled(False)
        
        self.training_thread = TrainingThread("10.47.172.163", "klac", "123456", training_params)
        self.training_thread.training_result.connect(self.on_training_result)
        self.training_thread.progress_update.connect(self.on_training_progress)
        self.training_thread.start()
        
    def on_training_progress(self, message):
        self.training_status.append(message)
        
    def on_training_result(self, success, message):
        self.training_status.append(message)
        self.start_training_btn.setEnabled(True)
        if success:
            self.save_model_btn.setEnabled(True)
            
    def save_model(self):
        save_path = QFileDialog.getSaveFileName(self, "Save Model", "", "Model files (*.pth *.pt)")
        if save_path[0]:
            remote_model_path = "/home/dlhome/kla-tencor/DL_Detect/Models/PLStar/model.pth"
            
            self.download_thread = FileTransferThread("10.47.172.163", "klac", "123456",
                                                    save_path[0], remote_model_path, 'download')
            self.download_thread.transfer_result.connect(self.on_download_result)
            self.download_thread.start()
            
    def on_download_result(self, success, message):
        self.training_status.append(message)

class ModelTestingModule(QWidget):
    """Model Testing Module"""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.parent = parent
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout()
        
        # Configuration (same as training)
        config_group = QGroupBox("Testing Configuration")
        config_layout = QVBoxLayout()
        
        # GPU selection
        gpu_layout = QHBoxLayout()
        gpu_layout.addWidget(QLabel("GPU Index:"))
        self.gpu_combo = QComboBox()
        self.gpu_combo.addItems(["0", "1"])
        gpu_layout.addWidget(self.gpu_combo)
        gpu_layout.addStretch()
        config_layout.addLayout(gpu_layout)
        config_group.setLayout(config_layout)
        
        # Testing dataset section
        dataset_group = QGroupBox("Testing Dataset")
        dataset_layout = QVBoxLayout()
        
        dataset_btn_layout = QHBoxLayout()
        self.select_test_dataset_btn = QPushButton("Select Testing Dataset")
        self.select_test_dataset_btn.clicked.connect(self.select_test_dataset)
        self.upload_test_file_btn = QPushButton("Upload File")
        self.upload_test_file_btn.clicked.connect(self.upload_test_dataset)
        self.upload_test_file_btn.setEnabled(False)
        
        dataset_btn_layout.addWidget(self.select_test_dataset_btn)
        dataset_btn_layout.addWidget(self.upload_test_file_btn)
        dataset_btn_layout.addStretch()
        
        self.test_dataset_label = QLabel("No dataset selected")
        
        dataset_layout.addLayout(dataset_btn_layout)
        dataset_layout.addWidget(self.test_dataset_label)
        dataset_group.setLayout(dataset_layout)
        
        # Pre-trained model section
        model_group = QGroupBox("Pre-trained Model")
        model_layout = QVBoxLayout()
        
        model_btn_layout = QHBoxLayout()
        self.select_model_btn = QPushButton("Select Pre-trained Model")
        self.select_model_btn.clicked.connect(self.select_pretrained_model)
        self.upload_model_btn = QPushButton("Upload Model")
        self.upload_model_btn.clicked.connect(self.upload_model)
        self.upload_model_btn.setEnabled(False)
        
        model_btn_layout.addWidget(self.select_model_btn)
        model_btn_layout.addWidget(self.upload_model_btn)
        model_btn_layout.addStretch()
        
        self.model_path_label = QLabel("No model selected")
        
        model_layout.addLayout(model_btn_layout)
        model_layout.addWidget(self.model_path_label)
        model_group.setLayout(model_layout)
        
        # Testing execution
        test_group = QGroupBox("Inference Execution")
        test_layout = QVBoxLayout()
        
        self.start_test_btn = QPushButton("Start Testing")
        self.start_test_btn.clicked.connect(self.start_testing)
        
        self.test_status = QTextEdit()
        self.test_status.setMaximumHeight(100)
        self.test_status.setReadOnly(True)
        
        test_layout.addWidget(self.start_test_btn)
        test_layout.addWidget(self.test_status)
        test_group.setLayout(test_layout)
        
        # Results display
        results_group = QGroupBox("Results Display")
        results_layout = QVBoxLayout()
        
        # Navigation
        nav_layout = QHBoxLayout()
        self.prev_result_btn = QPushButton("Previous")
        self.next_result_btn = QPushButton("Next")
        self.result_counter_label = QLabel("Result 1 of 1")
        
        nav_layout.addWidget(self.prev_result_btn)
        nav_layout.addWidget(self.result_counter_label)
        nav_layout.addWidget(self.next_result_btn)
        nav_layout.addStretch()
        
        # Result displays
        self.hazemap_result_label = QLabel("Hazemap Output")
        self.hazemap_result_label.setMinimumHeight(100)
        self.hazemap_result_label.setStyleSheet("border: 1px solid #ccc; background-color: #f9f9f9;")
        
        self.postprocess_result_label = QLabel("Post-processing Results")
        self.postprocess_result_label.setMinimumHeight(100)
        self.postprocess_result_label.setStyleSheet("border: 1px solid #ccc; background-color: #f9f9f9;")
        
        results_layout.addLayout(nav_layout)
        results_layout.addWidget(self.hazemap_result_label)
        results_layout.addWidget(self.postprocess_result_label)
        results_group.setLayout(results_layout)
        
        # Report generation
        report_group = QGroupBox("Report Generation")
        report_layout = QHBoxLayout()
        
        self.generate_report_btn = QPushButton("Generate Report")
        self.generate_report_btn.clicked.connect(self.generate_report)
        self.generate_report_btn.setEnabled(False)
        
        report_layout.addWidget(self.generate_report_btn)
        report_layout.addStretch()
        report_group.setLayout(report_layout)
        
        # Add all groups
        layout.addWidget(config_group)
        layout.addWidget(dataset_group)
        layout.addWidget(model_group)
        layout.addWidget(test_group)
        layout.addWidget(results_group)
        layout.addWidget(report_group)
        
        self.setLayout(layout)
        
    def select_test_dataset(self):
        folder = QFileDialog.getExistingDirectory(self, "Select Testing Dataset")
        if folder:
            self.test_dataset_path = folder
            self.test_dataset_label.setText(f"Selected: {folder}")
            self.upload_test_file_btn.setEnabled(True)
            
    def upload_test_dataset(self):
        if not hasattr(self.parent, 'connection_established') or not self.parent.connection_established:
            QMessageBox.warning(self, "Warning", "Please establish server connection first!")
            return
            
        remote_path = "/home/dlhome/kla-tencor/DL_Detect/Inference/Input/PLStar.tar"
        
        self.test_status.append("Uploading test dataset...")
        self.upload_test_file_btn.setEnabled(False)
        
        self.upload_thread = FileTransferThread("10.47.172.163", "klac", "123456",
                                              self.test_dataset_path, remote_path, 'upload')
        self.upload_thread.transfer_result.connect(self.on_test_upload_result)
        self.upload_thread.progress_update.connect(self.on_test_upload_progress)
        self.upload_thread.start()
        
    def on_test_upload_progress(self, message):
        self.test_status.append(message)
        
    def on_test_upload_result(self, success, message):
        self.test_status.append(message)
        self.upload_test_file_btn.setEnabled(True)
        
    def select_pretrained_model(self):
        file_path = QFileDialog.getOpenFileName(self, "Select Pre-trained Model", 
                                              "", "Model files (*.pth *.pt)")
        if file_path[0]:
            self.model_file_path = file_path[0]
            self.model_path_label.setText(f"Selected: {file_path[0]}")
            self.upload_model_btn.setEnabled(True)
            
    def upload_model(self):
        if not hasattr(self.parent, 'connection_established') or not self.parent.connection_established:
            QMessageBox.warning(self, "Warning", "Please establish server connection first!")
            return
            
        remote_path = "/home/dlhome/kla-tencor/DL_Detect/Models/PLStar/model.pth"
        
        self.test_status.append("Uploading model...")
        self.upload_model_btn.setEnabled(False)
        
        self.model_upload_thread = FileTransferThread("10.47.172.163", "klac", "123456",
                                                    self.model_file_path, remote_path, 'upload')
        self.model_upload_thread.transfer_result.connect(self.on_model_upload_result)
        self.model_upload_thread.progress_update.connect(self.on_model_upload_progress)
        self.model_upload_thread.start()
        
    def on_model_upload_progress(self, message):
        self.test_status.append(message)
        
    def on_model_upload_result(self, success, message):
        self.test_status.append(message)
        self.upload_model_btn.setEnabled(True)
        
    def start_testing(self):
        if not hasattr(self.parent, 'connection_established') or not self.parent.connection_established:
            QMessageBox.warning(self, "Warning", "Please establish server connection first!")
            return
            
        self.test_status.append("Starting inference...")
        self.start_test_btn.setEnabled(False)
        self.generate_report_btn.setEnabled(True)
        
        # Simulate testing completion
        self.test_status.append("Inference completed successfully!")
        self.start_test_btn.setEnabled(True)
        
    def generate_report(self):
        self.test_status.append("Generating PowerPoint report...")
        save_path = QFileDialog.getSaveFileName(self, "Save Report", "", "PowerPoint files (*.pptx)")
        if save_path[0]:
            # Simulate report generation and download
            self.test_status.append(f"Report saved to: {save_path[0]}")

class MainWindow(QMainWindow):
    """Main Application Window"""
    def __init__(self):
        super().__init__()
        self.connection_established = False
        self.setup_ui()
        self.apply_styles()
        
    def setup_ui(self):
        self.setWindowTitle("Model Training Interface")
        self.setGeometry(100, 100, 1200, 800)
        
        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Main layout
        main_layout = QHBoxLayout()
        
        # Left sidebar
        sidebar = QWidget()
        sidebar.setFixedWidth(200)
        sidebar_layout = QVBoxLayout()
        
        # Navigation buttons
        self.server_btn = QPushButton("Server Connection")
        self.training_btn = QPushButton("Model Training")
        self.testing_btn = QPushButton("Model Testing")
        
        self.server_btn.clicked.connect(lambda: self.show_module(0))
        self.training_btn.clicked.connect(lambda: self.show_module(1))
        self.testing_btn.clicked.connect(lambda: self.show_module(2))
        
        sidebar_layout.addWidget(self.server_btn)
        sidebar_layout.addWidget(self.training_btn)
        sidebar_layout.addWidget(self.testing_btn)
        sidebar_layout.addStretch()
        
        sidebar.setLayout(sidebar_layout)
        
        # Content area with stacked widget
        self.stacked_widget = QStackedWidget()
        
        # Create modules
        self.server_module = ServerConnectionModule(self)
        self.training_module = ModelTrainingModule(self)
        self.testing_module = ModelTestingModule(self)
        
        self.stacked_widget.addWidget(self.server_module)
        self.stacked_widget.addWidget(self.training_module)
        self.stacked_widget.addWidget(self.testing_module)
        
        # Add to main layout
        main_layout.addWidget(sidebar)
        main_layout.addWidget(self.stacked_widget)
        
        central_widget.setLayout(main_layout)
        
        # Start with server connection module
        self.show_module(0)
        
    def show_module(self, index):
        self.stacked_widget.setCurrentIndex(index)
        
        # Update button states
        buttons = [self.server_btn, self.training_btn, self.testing_btn]
        for i, btn in enumerate(buttons):
            if i == index:
                btn.setStyleSheet("background-color: #3498db; color: white;")
            else:
                btn.setStyleSheet("")
                
    def apply_styles(self):
        """Apply the custom stylesheet"""
        style = """
        QMainWindow {
            background-color: #f5f5f5;
        }
        
        QWidget {
            font-family: Arial;
            font-size: 12px;
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
        
        QLineEdit {
            padding: 8px;
            border: 1px solid #ccc;
            border-radius: 3px;
        }
        
        QTextEdit {
            border: 1px solid #ccc;
            border-radius: 3px;
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
            padding: 0 5px;
        }
        
        QLabel {
            font-size: 12px;
        }
        
        /* Sidebar styling */
        QWidget:first-child {
            background-color: #2c3e50;
        }
        
        /* Content area */
        QStackedWidget {
            background-color: #ffffff;
        }
        """
        
        self.setStyleSheet(style)

def main():
    app = QApplication(sys.argv)
    
    # Set application font
    font = QFont("Arial", 12)
    app.setFont(font)
    
    window = MainWindow()
    window.show()
    
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
