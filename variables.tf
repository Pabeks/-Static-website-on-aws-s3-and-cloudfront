variable "bucket_name" {
  description = "The name of the S3 bucket."
  type        = string
}

variable "index_html_key" {
  description = "The key (path) for the index.html file in the S3 bucket."
  type        = string
}

variable "index_html_path" {
  description = "The local path to the index.html file."
  type        = string
}

# variable "s3_bucket_id " {
#     type = string
#     description = "id of the s3 bucket"

# }
