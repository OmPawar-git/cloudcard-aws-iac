output "alb_dns_name" {
  description = "Open this URL in browser to see the live website"
  value       = aws_lb.app.dns_name
}

output "rds_endpoint" {
  description = "Use this in your website's index.php database config"
  value       = aws_db_instance.app.address
}

output "s3_bucket" {
  value = aws_s3_bucket.assets.bucket
}
