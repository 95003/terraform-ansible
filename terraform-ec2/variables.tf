variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "key_pair_name" {
  description = "Name of the key pair"
  default     = "indexer-key"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.medium"
}
