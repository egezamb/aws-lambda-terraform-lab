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
  description = "EventBridge Scheduler expression: rate(...), cron(...) or at(...). The lab spec is every 2 minutes."
  type        = string
  default     = "rate(2 minutes)"

  # The provider passes any string through, so a typo would only fail at apply.
  validation {
    condition = can(regex(
      "^(rate\\([1-9][0-9]* (minute|minutes|hour|hours|day|days)\\)|cron\\([^)]+\\)|at\\([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\))$",
      var.schedule_rate
    ))
    error_message = "schedule_rate must be rate(<n> minutes|hours|days), cron(...) or at(yyyy-mm-ddThh:mm:ss)."
  }
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

  # The code is Python, but the provider accepts any Lambda runtime, such as nodejs20.x.
  validation {
    condition     = can(regex("^python3\\.[0-9]+$", var.lambda_runtime))
    error_message = "lambda_runtime must be a Python 3 runtime such as python3.12; both functions are Python."
  }
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

variable "api_rate_limit" {
  description = "Steady requests per second each API Gateway stage (HTTP and REST) accepts before answering 429."
  type        = number
  default     = 5

  validation {
    condition     = var.api_rate_limit > 0
    error_message = "api_rate_limit must be above 0; 0 would refuse every request."
  }
}

variable "greeter_max_concurrency" {
  description = "Reserved concurrency for the greeter: the most invocations it runs at once, through the Function URL and both APIs together. -1 (default) reserves none. The Function URL has no throttle of its own, so this is its only cap. AWS keeps 10 of an account's concurrency unreserved, so on an account with a low total limit a reservation can fail."
  type        = number
  default     = -1

  validation {
    condition     = var.greeter_max_concurrency == -1 || (var.greeter_max_concurrency >= 1 && floor(var.greeter_max_concurrency) == var.greeter_max_concurrency)
    error_message = "greeter_max_concurrency must be -1 (no reservation) or a whole number of at least 1; 0 would refuse every call."
  }
}

variable "api_burst_limit" {
  description = "Requests each API Gateway stage accepts at once above the steady rate."
  type        = number
  default     = 10

  validation {
    condition     = var.api_burst_limit >= 1 && floor(var.api_burst_limit) == var.api_burst_limit
    error_message = "api_burst_limit must be a whole number of at least 1."
  }
}
