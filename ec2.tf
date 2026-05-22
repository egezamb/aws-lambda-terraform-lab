data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "lab_test" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name    = "${var.project_name}-test-instance"
    Purpose = "Target for scheduled stop Lambda (Exercise 1)"
  }
}
