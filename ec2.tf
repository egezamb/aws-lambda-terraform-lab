# "al2023-ami-2023.*", not "al2023-ami-*": the looser pattern also matches the minimal
# (al2023-ami-minimal-...) and ECS-optimized (al2023-ami-ecs-hvm-...) images, and most_recent can
# pick one of those. A name filter rather than the public SSM parameter, which the Learner Lab's
# restricted permissions may not allow reading.
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
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

  # Encrypted at rest with the AWS-managed EBS key; gp3 is cheaper than gp2 for the same size.
  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name    = "${var.project_name}-test-instance"
    Purpose = "Target for scheduled stop Lambda (Exercise 1)"
  }
}
