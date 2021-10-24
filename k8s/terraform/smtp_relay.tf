
data "dme_domain" "external_domain" {
  name = var.external_domain
}

resource "aws_ses_domain_identity" "external_domain" {
  domain = var.external_domain
}

resource "aws_ses_domain_mail_from" "example" {
  domain           = aws_ses_domain_identity.external_domain.domain
  mail_from_domain = "bounce.${aws_ses_domain_identity.external_domain.domain}"
}

resource "dme_dns_record" "ses_verification" {
  domain_id = data.dme_domain.external_domain.id
  name      = "_amazonses"
  type      = "TXT"
  ttl       = 600
  value     = aws_ses_domain_identity.external_domain.verification_token
}

# Example Route53 MX record
resource "dme_dns_record" "example_ses_domain_mail_from_mx" {
  domain_id = data.dme_domain.external_domain.id
  name      = "bounce"
  type      = "MX"
  ttl       = 600
  value     = "feedback-smtp.${local.aws_region}.amazonses.com." # Change to the region in which `aws_ses_domain_identity.example` is created
  mx_level  = 10
}

# Example Route53 TXT record for SPF
resource "dme_dns_record" "example_ses_domain_mail_from_txt" {
  domain_id = data.dme_domain.external_domain.id
  name      = "bounce"
  type      = "TXT"
  ttl       = 600
  value     = "v=spf1 include:amazonses.com -all"
}

resource "aws_ses_domain_identity_verification" "ses_verification" {
  domain     = aws_ses_domain_identity.external_domain.id
  depends_on = [dme_dns_record.ses_verification]
}

resource "aws_sns_topic" "external_domain_feedback" {
  name = "email-feedback"
}

resource "kubernetes_namespace" "network" {
  metadata {
    name = "network"
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
}

resource "kubernetes_secret" "dkim_private_keys" {
  metadata {
    name = "smtp-dkim-keys"
    namespace = kubernetes_namespace.network.metadata[0].name
  }

  data = {
    "${var.external_domain}.private" = tls_private_key.dkim_key.private_key_pem
  }
}

resource "tls_private_key" "dkim_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "dme_dns_record" "dkim_key" {
  domain_id = data.dme_domain.external_domain.id
  name      = "${local.dkim_key_name}._domainkey"
  type      = "TXT"
  ttl       = 600
  value     = "v=DKIM1; h=sha256; k=rsa; s=email; p=${local.dkim_public_key}"
  # value     = "v=DKIM1; k=rsa; \\\" \\\"p=${substr(local.dkim_public_key, 0, 250)}\\\" \\\"${substr(local.dkim_public_key, 250, 250)}"
  # description = tls_private_key.dkim_key.public_key_fingerprint_md5
  lifecycle {    
    ignore_changes = [
      # value
    ]
  }
}

resource "aws_ses_identity_notification_topic" "external_domain_bounce" {
  topic_arn                = aws_sns_topic.external_domain_feedback.arn
  notification_type        = "Bounce"
  identity                 = aws_ses_domain_identity.external_domain.domain
  include_original_headers = true
}
resource "aws_ses_identity_notification_topic" "external_domain_complaint" {
  topic_arn                = aws_sns_topic.external_domain_feedback.arn
  notification_type        = "Complaint"
  identity                 = aws_ses_domain_identity.external_domain.domain
  include_original_headers = true
}
resource "aws_ses_identity_notification_topic" "external_domain_delivery" {
  topic_arn                = aws_sns_topic.external_domain_feedback.arn
  notification_type        = "Delivery"
  identity                 = aws_ses_domain_identity.external_domain.domain
  include_original_headers = true
}


resource "aws_ses_domain_dkim" "external_domain" {
  domain = aws_ses_domain_identity.external_domain.domain
}

resource "dme_dns_record" "dkim_record" {
  count     = 3
  domain_id = data.dme_domain.external_domain.id
  name      = "${element(aws_ses_domain_dkim.external_domain.dkim_tokens, count.index)}._domainkey"
  type      = "CNAME"
  ttl       = 600
  value     = "${element(aws_ses_domain_dkim.external_domain.dkim_tokens, count.index)}.dkim.amazonses.com."
}

# need iam user
resource "aws_iam_user" "smtp_iam_user" {
  name          = "smtp-user-for-home-cluster"
  force_destroy = true
}

# policy
data "aws_iam_policy_document" "send_raw_email_policy_document" {
  statement {
    actions = [
      "ses:SendRawEmail"
    ]
    resources = ["*"]
  }
}
resource "aws_iam_policy" "send_raw_email_policy" {
  name        = "SESSendRawEmail-home-cluster"
  description = "Allow to send raw email via smtp via SES"
  policy      = data.aws_iam_policy_document.send_raw_email_policy_document.json
}

# send ses email policy attachment
resource "aws_iam_user_policy_attachment" "repo-access-attach" {
  user       = aws_iam_user.smtp_iam_user.name
  policy_arn = aws_iam_policy.send_raw_email_policy.arn
}
# need credentials
resource "aws_iam_access_key" "credentials_for_smtp_user" {
  user = aws_iam_user.smtp_iam_user.name
}

locals {
  smtp_host = "email-smtp.${local.aws_region}.amazonaws.com:587"
  smtp_user = aws_iam_access_key.credentials_for_smtp_user.id
  smtp_pass = aws_iam_access_key.credentials_for_smtp_user.ses_smtp_password_v4

  dkim_key_name = "home-cluster"
  # dkim_private_key = tls_private_key.dkim_key.private_key_pem

  dkim_public_key = replace(replace(tls_private_key.dkim_key.public_key_pem, "\n", ""), "/-----.*?-----/", "")
}
