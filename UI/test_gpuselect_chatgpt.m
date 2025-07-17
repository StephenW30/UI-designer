#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
training_ui.py
A PyQt5-based Windows application for training UI:
- Connect to remote Linux GPU server via SSH
- Transfer local folder files to remote server
- Select available GPUs on remote server
- Start training remotely
"""

import sys
import os
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QGroupBox, QVBoxLayout, QHBoxLayout,
    QLabel, QLineEdit, QPushButton, QListWidget, QFileDialog, QMessageBox, QStatusBar
)
import paramiko

class TrainingUI(QMainWindow):
    def __init__(self):
        super().__init__()
        self.ssh_client = None
        self.sftp_client = None
        self.init_ui()

    def init_ui(self):
        self.setWindowTitle("训练UI")
        self.setGeometry(100, 100, 600, 500)

        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout()
        central_widget.setLayout(main_layout)

        # 连接服务器
        conn_group = QGroupBox("连接服务器")
        conn_layout = QHBoxLayout()
        conn_group.setLayout(conn_layout)
        self.host_edit = QLineEdit()
        self.host_edit.setPlaceholderText("主机地址 e.g. 192.168.1.100")
        self.port_edit = QLineEdit("22")
        self.port_edit.setFixedWidth(60)
        self.user_edit = QLineEdit()
        self.user_edit.setPlaceholderText("用户名")
        self.pass_edit = QLineEdit()
        self.pass_edit.setPlaceholderText("密码")
        self.pass_edit.setEchoMode(QLineEdit.Password)
        conn_layout.addWidget(QLabel("Host:"))
        conn_layout.addWidget(self.host_edit)
        conn_layout.addWidget(QLabel("Port:"))
        conn_layout.addWidget(self.port_edit)
        conn_layout.addWidget(QLabel("User:"))
        conn_layout.addWidget(self.user_edit)
        conn_layout.addWidget(QLabel("Pass:"))
        conn_layout.addWidget(self.pass_edit)
        self.connect_btn = QPushButton("连接")
        self.connect_btn.clicked.connect(self.connect_to_server)
        conn_layout.addWidget(self.connect_btn)
        main_layout.addWidget(conn_group)

        # 文件传输
        transfer_group = QGroupBox("文件传输")
        transfer_layout = QHBoxLayout()
        transfer_group.setLayout(transfer_layout)
        self.local_path_edit = QLineEdit()
        self.local_path_edit.setReadOnly(True)
        self.select_local_btn = QPushButton("选择本地文件夹")
        self.select_local_btn.clicked.connect(self.select_local_folder)
        transfer_layout.addWidget(self.local_path_edit)
        transfer_layout.addWidget(self.select_local_btn)
        self.remote_path_edit = QLineEdit("/home/user/")
        self.remote_path_edit.setPlaceholderText("远程路径 e.g. /home/user/project")
        self.upload_btn = QPushButton("上传")
        self.upload_btn.clicked.connect(self.upload_folder)
        transfer_layout.addWidget(QLabel("Remote:"))
        transfer_layout.addWidget(self.remote_path_edit)
        transfer_layout.addWidget(self.upload_btn)
        main_layout.addWidget(transfer_group)

        # GPU 选择
        gpu_group = QGroupBox("GPU 选择")
        gpu_layout = QVBoxLayout()
        gpu_group.setLayout(gpu_layout)
        self.refresh_gpu_btn = QPushButton("刷新GPU列表")
        self.refresh_gpu_btn.clicked.connect(self.refresh_gpu_list)
        gpu_layout.addWidget(self.refresh_gpu_btn)
        self.gpu_list_widget = QListWidget()
        self.gpu_list_widget.setSelectionMode(QListWidget.MultiSelection)
        gpu_layout.addWidget(self.gpu_list_widget)
        main_layout.addWidget(gpu_group)

        # 开始训练
        self.start_btn = QPushButton("开始训练")
        self.start_btn.clicked.connect(self.start_training)
        main_layout.addWidget(self.start_btn)

        # 状态栏
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)

    def connect_to_server(self):
        host = self.host_edit.text().strip()
        port = int(self.port_edit.text().strip())
        user = self.user_edit.text().strip()
        password = self.pass_edit.text().strip()
        try:
            self.ssh_client = paramiko.SSHClient()
            self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.ssh_client.connect(host, port=port, username=user, password=password)
            self.sftp_client = self.ssh_client.open_sftp()
            self.status_bar.showMessage("已连接到服务器")
        except Exception as e:
            QMessageBox.critical(self, "连接失败", str(e))
            self.status_bar.showMessage("连接失败")

    def select_local_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "选择本地文件夹", os.getcwd())
        if folder:
            self.local_path_edit.setText(folder)

    def upload_folder(self):
        if not self.sftp_client:
            QMessageBox.warning(self, "警告", "请先连接到服务器")
            return
        local_folder = self.local_path_edit.text().strip()
        remote_folder = self.remote_path_edit.text().strip()
        for root, dirs, files in os.walk(local_folder):
            rel_path = os.path.relpath(root, local_folder)
            remote_path = os.path.join(remote_folder, rel_path).replace('\\', '/')
            try:
                self.sftp_client.listdir(remote_path)
            except IOError:
                self.sftp_client.mkdir(remote_path)
            for file in files:
                local_file = os.path.join(root, file)
                remote_file = remote_path + "/" + file
                self.sftp_client.put(local_file, remote_file)
        self.status_bar.showMessage("上传完成")

    def refresh_gpu_list(self):
        if not self.ssh_client:
            QMessageBox.warning(self, "警告", "请先连接到服务器")
            return
        stdin, stdout, stderr = self.ssh_client.exec_command(
            "nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used --format=csv,noheader,nounits"
        )
        output = stdout.read().decode('utf-8').strip().splitlines()
        self.gpu_list_widget.clear()
        for line in output:
            parts = [p.strip() for p in line.split(',')]
            index, name, util, mem = parts
            item_text = f"GPU {index}: {name}, 利用率 {util}%, 已用显存 {mem}MiB"
            self.gpu_list_widget.addItem(item_text)
        self.status_bar.showMessage("GPU 列表已刷新")

    def start_training(self):
        if not self.ssh_client:
            QMessageBox.warning(self, "警告", "请先连接到服务器")
            return
        selected = [item.text().split()[1].strip(':') for item in self.gpu_list_widget.selectedItems()]
        if not selected:
            QMessageBox.warning(self, "警告", "请选择至少一个GPU")
            return
        gpu_ids = ",".join(selected)
        remote_folder = self.remote_path_edit.text().strip()
        cmd = f"cd {remote_folder} && CUDA_VISIBLE_DEVICES={gpu_ids} python train.py"
        self.ssh_client.exec_command(cmd)
        self.status_bar.showMessage(f"已在远程启动训练: GPU={gpu_ids}")

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = TrainingUI()
    window.show()
    sys.exit(app.exec_())
