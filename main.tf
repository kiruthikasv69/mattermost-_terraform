resource "aws_vpc" "mattermost_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "mattermost-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.mattermost_vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = var.az
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mattermost_vpc.id

  tags = {
    Name = "mattermost-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.mattermost_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "mattermost_sg" {
  name        = "mattermost-sg"
  description = "Allow HTTP, HTTPS and SSH"
  vpc_id      = aws_vpc.mattermost_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8065
    to_port     = 8065
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mattermost-sg"
  }
}

resource "aws_instance" "mattermost" {
  ami                    = var.ami_id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public_subnet.id
  key_name               = var.key_name
  security_groups        = [aws_security_group.mattermost_sg.id]
  associate_public_ip_address = true

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
      "sudo bash -c 'cat > /lib/systemd/system/mattermost.service <<EOF\n[Unit]\nDescription=Mattermost\nAfter=network.target\n\n[Service]\nType=simple\nUser=mattermost\nGroup=mattermost\nWorkingDirectory=/opt/mattermost\nExecStart=/opt/mattermost/bin/mattermost\nRestart=always\nLimitNOFILE=49152\n\n[Install]\nWantedBy=multi-user.target\nEOF'",
      "sudo systemctl daemon-reexec",
      "sudo systemctl enable mattermost",
      "sudo systemctl start mattermost"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "Mattermost-Server"
  }
}
