variable "aws_region" {
  description = "AWS region to deploy lab resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used to prefix resources"
  type        = string
  default     = "lab10-lambda"
}

variable "lab_role_name" {
  description = "Name of the pre-existing AWS Learner Lab role. Production rebuild would create dedicated roles per Lambda."
  type        = string
  default     = "LabRole"
}

variable "schedule_rate" {
  description = "Rate expression for the EventBridge schedule (matches lab spec: 2 minutes)"
  type        = string
  default     = "rate(2 minutes)"
}

variable "instance_type" {
  description = "EC2 instance type for the test instance"
  type        = string
  default     = "t3.micro"
}

variable "lambda_runtime" {
  description = "Python runtime version for Lambda functions"
  type        = string
  default     = "python3.12"
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "your_name" {
  description = "Your first name for the greeter test event (used in outputs as sample curl command)"
  type        = string
  default     = "Ege"
}
