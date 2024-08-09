packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# variable to select ubuntu AMI
variable "use_ubuntu" {
  type    = bool
  default = true
}

# variable to select redhat AMI
variable "use_redhat" {
  type    = bool
  default = false
}

variable "ami_prefix" {
  type    = string
  default = "onyeka"
}

variable "ami_tag" {
  type    = string
  default = ""
}
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}


# ubuntu source block
source "amazon-ebs" "ubuntu" {
  ami_name      = "${var.ami_prefix}-ubuntu-${local.timestamp}"
  instance_type = "t3.micro"
  region        = var.aws_region
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }
  ssh_username = "ubuntu"
  tags = {
    "Name"        = "${ami_tag}"
    "Environment" = "development"
    "OS_Version"  = "Ubuntu 20.04"
    "Release"     = "Latest"
    "Created-by"  = "Packer"
  }
}

# redhat source block
source "amazon-ebs" "redhat" {
  ami_name      = "${var.ami_prefix}-redhat-${local.timestamp}"
  instance_type = "t3.micro"
  region        = var.aws_region
  source_ami_filter {
    filters = {
      name                = "RHEL-8.4.0_HVM-*-x86_64-*-Hourly2-GP2"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["309956199498"] # Red Hat
  }
  ssh_username = "ec2-user"
  tags = {
    "Name"        = "${ami_tag}"
    "Environment" = "development"
    "OS_Version"  = "RHEL 8.4"
    "Release"     = "Latest"
    "Created-by"  = "Packer"
  }
}

# The build command is selecting a source for building the image based on the values of var.use_ubuntu and 
# var.use_redhat. If var.use_ubuntu is true, the Ubuntu source is selected. If var.use_ubuntu is false and
#  var.use_redhat is true, the Red Hat source is selected. If both are false, no sources are selected.
build {
  sources = var.use_ubuntu ? ["source.amazon-ebs.ubuntu"] : var.use_redhat ? ["source.amazon-ebs.redhat"] : []

  provisioner "file" {
    source      = "security-scripts"
    destination = "/tmp"
  }

  provisioner "shell" {
    inline = concat(
      var.use_ubuntu ? ["sudo apt update -y"] : [],
      var.use_redhat ? ["sudo yum update -y"] : [],
      [
        "sudo bash /tmp/security-scripts/001-critical-standards.sh",
        "sudo bash /tmp/security-scripts/002-critical-standards.sh"
      ]
    )
  }

   provisioner "shell" {
    inline = ["echo This provisioner runs last"]
  }
}
