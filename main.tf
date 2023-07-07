#------------------Provider Info--------------------------------
provider "aws" {
  region                   = "ap-south-1"
  #profile                  = "terraformp"
}
#-----------------Fetching Ubuntu AMI---------------------------
data "aws_ami" "ubuntu-ami" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20230516"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}
#-----------------Private Key File------------------------------
variable "ssh_private_key_file" {
  default = "/var/tmp/Jenkins-Server.pem"
}

locals {
  ssh_private_key_content = file(var.ssh_private_key_file)
}
resource "null_resource" "key" {
  provisioner "local-exec" {
    on_failure  = fail
    command = "sudo cp /var/tmp/Jenkins-Server.pem /home/ubuntu/.ssh/Jenkins-Server.pem"
  }
}
#---------------Creating Inventory-------------------------------
resource "null_resource" "inventory" {
  provisioner "local-exec" {
    on_failure  = fail
    command = "echo '[servers]' > hosts"
  }
}
#---------------Passwordless SSH----------------------------------
resource "null_resource" "Transfer_ssh1" {
  depends_on = [null_resource.key]
  provisioner "local-exec" {
    on_failure = fail
    command = "sudo echo 'Host *\n\tStrictHostKeyChecking no\n\tUser ubuntu\n\tIdentityFile /home/ubuntu/.ssh/Jenkins-Server.pem' > config"
  }
}
resource "null_resource" "Transfer_ssh2" {
  depends_on = [null_resource.Transfer_ssh1]
  provisioner "local-exec" {
    on_failure = fail
    command = "sudo cp config /home/ubuntu/.ssh/config"
  }
}

#-----------------Ansibe Host---------------------------------------
resource "aws_instance" "ansible-hosts" {
  ami = data.aws_ami.ubuntu-ami.id
  instance_type = "t2.micro"
  key_name = "Jenkins-Server"

  tags = {
    Name = "terr-ansible-host"
  }
}
#----------------Inventory File--------------------------------------
resource "null_resource" "inventory-file" {
  depends_on = [aws_instance.ansible-hosts,null_resource.inventory]
  provisioner "local-exec" {
    on_failure = fail
    command = "echo ${aws_instance.ansible-hosts.tags["Name"]} ansible_host=${aws_instance.ansible-hosts.public_ip} ansible_connection=ssh ansible_user=ubuntu >> hosts"
  }
}
#--------------Ping--------------------------------------------------
resource "null_resource" "ping" {
  depends_on = [null_resource.inventory-file]
  provisioner "local-exec" {
    on_failure = fail
    command = "ansible servers -m ping -i hosts"
  }
}
