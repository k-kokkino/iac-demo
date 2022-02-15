variable "dbuser" {
  description = "The username for the DB master user"
  type        = string
  sensitive   = true
}

variable "dbpass" {
  description = "The password for the DB master user"
  type        = string
  sensitive   = true
}