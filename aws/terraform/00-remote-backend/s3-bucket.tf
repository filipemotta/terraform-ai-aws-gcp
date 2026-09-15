# State bucket: versioned, encrypted at rest, never public.
# Native S3 locking (use_lockfile = true) needs no DynamoDB table.

resource "aws_s3_bucket" "this" {
  bucket        = var.remote_backend.name
  force_destroy = var.remote_backend.force_destroy

  tags = {
    Name = "terraform-state-bucket-atlas-useast1"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.remote_backend.sse_algorithm
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
