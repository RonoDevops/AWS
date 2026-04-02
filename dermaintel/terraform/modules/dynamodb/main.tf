################################################################################
# DynamoDB Module - DermaIntel Papers Index & Feedback Tables
# Single-table design for dermatology research paper indexing
################################################################################

resource "aws_dynamodb_table" "papers_index" {
  name         = "dermaintel-papers-index-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI2PK"
    type = "S"
  }

  attribute {
    name = "GSI3PK"
    type = "S"
  }

  attribute {
    name = "paper_id"
    type = "S"
  }

  attribute {
    name = "pub_date"
    type = "S"
  }

  # GSI1 - DrugIndex: look up papers by drug name
  global_secondary_index {
    name            = "DrugIndex"
    hash_key        = "GSI1PK"
    range_key       = "SK"
    projection_type = "ALL"
  }

  # GSI2 - JournalIndex: look up papers by journal
  global_secondary_index {
    name            = "JournalIndex"
    hash_key        = "GSI2PK"
    range_key       = "SK"
    projection_type = "ALL"
  }

  # GSI3 - StudyTypeIndex: look up papers by study type
  global_secondary_index {
    name            = "StudyTypeIndex"
    hash_key        = "GSI3PK"
    range_key       = "SK"
    projection_type = "ALL"
  }

  # GSI4 - PaperIdIndex: deduplication lookups by paper_id
  global_secondary_index {
    name            = "PaperIdIndex"
    hash_key        = "paper_id"
    range_key       = "pub_date"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  ttl {
    attribute_name = "ttl"
    enabled        = false
  }

  tags = merge(var.tags, {
    Name        = "dermaintel-papers-index-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  })
}

################################################################################
# Feedback Table
################################################################################

resource "aws_dynamodb_table" "feedback" {
  name         = "dermaintel-feedback-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "timestamp#query_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "timestamp#query_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Name        = "dermaintel-feedback-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  })
}

################################################################################
# Chat History Table - Stores doctor chatbot conversation history
################################################################################

resource "aws_dynamodb_table" "chat_history" {
  name         = "dermaintel-chat-history-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "session_id"
    type = "S"
  }

  # GSI - SessionIndex: look up all turns in a session
  global_secondary_index {
    name            = "SessionIndex"
    hash_key        = "session_id"
    range_key       = "SK"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Name        = "dermaintel-chat-history-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  })
}
