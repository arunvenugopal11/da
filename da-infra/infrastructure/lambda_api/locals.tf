locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  prefix     = "da-${var.env_name}"

  # Lambda functions to create — add new services here
  functions = {
    auth = {
      handler     = "dist/handlers/auth.handler"
      description = "Authentication — phone OTP, JWT issuance"
      timeout     = 10
      memory_mb   = 256
    }
    profile = {
      handler     = "dist/handlers/profile.handler"
      description = "User profile CRUD, photo management"
      timeout     = 15
      memory_mb   = 256
    }
    matching = {
      handler     = "dist/handlers/matching.handler"
      description = "Match discovery — nearby, new, daily recommendations"
      timeout     = 30
      memory_mb   = 512
    }
    premium = {
      handler     = "dist/handlers/premium.handler"
      description = "Premium plan gating and feature checks"
      timeout     = 10
      memory_mb   = 128
    }
    stripe_webhook = {
      handler     = "dist/handlers/stripe-webhook.handler"
      description = "Stripe webhook — activates/deactivates premium on billing events"
      timeout     = 10
      memory_mb   = 128
    }
    notifications = {
      handler     = "dist/handlers/notifications.handler"
      description = "Push notification sender — triggered by SQS"
      timeout     = 15
      memory_mb   = 128
    }
    chat = {
      handler     = "dist/handlers/chat.handler"
      description = "WebSocket chat — connect/disconnect/message"
      timeout     = 29 # API Gateway WebSocket hard limit is 29s
      memory_mb   = 256
    }
  }
}
