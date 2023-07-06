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

resource "aws_instance" "myInstanceAWS" {
  ami = data.aws_ami.amazon-linux.id
  instance_type = "t2.micro"
  #key_name = "Jenkins-Server"

  tags = {
    Name = "terr-ansible-host"
  }
}

# data  "template_file" "hosts" {
#     template = "${file("./templates/hosts.tpl")}"
#     vars {
#         hosts_ips = "${join("\n", aws_instance.terr-ansible-host.public_ip)}"
#     }
# }

# resource "local_file" "hosts_file" {
#   content  = "${data.template_file.hosts.rendered}"
#   filename = "./inventory/hosts"
# }

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
    private_key = file("~/.ssh/Jenkins-Server.pem")
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install python-setuptools python-pip -y",
      "sudo pip install httplib2"
    ]
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
