resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = var.instance_type
  tags = {
    Name = "${var.instance_name}-${random_id.suffix.hex}"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "app_repo" {
  name = "${var.ecr_repo_name}-${random_id.suffix.hex}"
}

resource "aws_codebuild_project" "app_build" {
  name         = "build-${random_id.suffix.hex}"
  service_role = aws_iam_role.codebuild_role.arn

  source {
    type     = "GITHUB"
    location = var.app_repo_url
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true

    environment_variable {
      name  = "REPO_URI"
      value = aws_ecr_repository.app_repo.repository_url
    }
  }
}

resource "aws_codepipeline" "pipeline" {
  name     = "pipeline-${random_id.suffix.hex}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        Owner      = var.github_owner
        Repo       = var.github_repo
        Branch     = "main"
        OAuthToken = var.github_token
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.app_build.name
      }
    }
  }
}

resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket        = "artifacts-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "codepipeline_custom_policy" {
  name = "codepipeline-custom-policy-${random_id.suffix.hex}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codecommit:GitPull",
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetDeployment",
          "iam:PassRole"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_custom_attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_custom_policy.arn
}


resource "aws_s3_bucket_policy" "allow_pipeline_access" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowCodePipelineAccess",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.codepipeline_role.arn
        },
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = "arn:aws:s3:::${aws_s3_bucket.codepipeline_artifacts.bucket}/*"
      }
    ]
  })
}
