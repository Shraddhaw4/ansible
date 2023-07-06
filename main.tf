provider "aws" {
  region                   = "ap-south-1"
  #profile                  = "terraformp"
}

data "aws_ami" "amazon-linux" {
  most_recent = true

  filter {
    name = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}


variable "ssh_private_key_file" {
  default = "/var/tmp/Jenkins-Server.pem"
}

locals {
  ssh_private_key_content = file(var.ssh_private_key_file)
}

resource "aws_instance" "myInstanceAWS" {
  ami = data.aws_ami.amazon-linux.id
  instance_type = "t2.micro"
  key_name = "Jenkins-Server"

  tags = {
    Name = "terr-ansible-host"
  }
}

resource "null_resource" "ConfigureAnsibleLabelVariable" {
  provisioner "local-exec" {
    command = "echo [webserver:vars] > hosts"
  }
  provisioner "local-exec" {
    command = "echo ansible_ssh_user=ec2-user >> hosts"
  }
  provisioner "local-exec" {
    command = "echo ansible_ssh_private_key_file=Jenkins-Server.pem >> hosts"
  }
  provisioner "local-exec" {
    command = "echo [webserver] >> hosts"
  }
}

resource "null_resource" "ProvisionRemoteHostsIpToAnsibleHosts" {
  depends_on = []
  connection {
    type = "ssh"
    user = "ec2-user"
    host = aws_instance.myInstanceAWS.public_ip
    private_key = local.ssh_private_key_content
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install python-setuptools python-pip -y",
      "sudo pip install httplib2",
      "cd ~/.ssh",
      "sudo chmod 600 *.pem",
      "echo -e 'Host *\n\tStrictHostKeyChecking no\n\tUser ubuntu\ntIdentityFile /home/ec2-user/.ssh/Jenkins-Server.pem' > config",
    ]
  }
  provisioner "file" {
    source      = "/var/tmp/Jenkins-Server.pem"
    destination = "/home/ec2-user/.ssh/Jenkins-Server.pem"
    on_failure  = fail

  }

  provisioner "local-exec" {
    command = "echo ${aws_instance.myInstanceAWS.public_ip} >> hosts"
  }
}

resource "null_resource" "ModifyApplyAnsiblePlayBook" {
  provisioner "local-exec" {
    command = "sed -i -e '/hosts:/ s/: .*/: webserver/' play.yml"   #change host label in playbook dynamically
  }

  provisioner "local-exec" {
    command = "sleep 10; ansible-playbook -i hosts play.yml"
  }
  depends_on = ["null_resource.ProvisionRemoteHostsIpToAnsibleHosts"]
}
