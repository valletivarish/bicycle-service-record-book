variable "region" {
  type    = string
  default = "us-east-1"
}

# t3.micro: burstable, 2 vCPU / 1 GiB, enough for the small Node container
# and the Nginx container; it idles at low CPU most of the time and earns burst credits.
# Fixed list instead of a lookup, so a new zone added by AWS never changes the
# subnets. Both zones offer t3.micro and db.t3.micro in the Learner Lab.
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "compose_version" {
  type    = string
  default = "v5.6.0"
}

# AWS Academy cannot create IAM roles, so EC2 uses the lab's existing profile
# (LabRole), which can read SSM parameters and pull from ECR.
variable "instance_profile" {
  type    = string
  default = "LabInstanceProfile"
}
