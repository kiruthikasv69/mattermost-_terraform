resource "aws_instance" "mattermost" {
  ami           = var.ami_id
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.private_subnet.id
  key_name      = var.key_name
  security_groups = [aws_security_group.mattermost_sg.id]

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install wget unzip -y",
      "wget https://releases.mattermost.com/9.3.0/mattermost-9.3.0-linux-amd64.tar.gz",
      "tar -xvzf mattermost-9.3.0-linux-amd64.tar.gz",
      "sudo mv mattermost /opt",
      "sudo useradd --system --user-group mattermost",
      "sudo mkdir /opt/mattermost/data",
      "sudo chown -R mattermost:mattermost /opt/mattermost",
      "sudo chmod -R g+w /opt/mattermost",
      # add more setup as needed
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}
