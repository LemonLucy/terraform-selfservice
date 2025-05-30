resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = var.instance_type
  tags = {
    Name = "${var.instance_name}" 
  }
}
# 1. AWS provider 설정
provider "aws" {
  region = var.aws_region
}
# 2. ECR 생성 (도커 이미지 저장소)
resource "aws_ecr_repository" "app_repo" {
  name = var.ecr_repo_name
}

# 3. CodeBuild 프로젝트
resource "aws_codebuild_project" "app_build" {
  name          = "build-${var.service_name}"
  service_role  = aws_iam_role.codebuild_role.arn
  source {
    type      = "GITHUB"
    location  = var.app_repo_url
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

# 4. CodePipeline 구성
resource "aws_codepipeline" "pipeline" {
  name     = "pipeline-${var.service_name}"
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    # location = var.s3_bucket
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
        Owner  = var.github_owner
        Repo   = var.github_repo
        Branch = "main"
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

# s3 bucket for cicd
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket        = "${var.service_name}-artifacts-${random_id.bucket_suffix.hex}"
  force_destroy = true
}
