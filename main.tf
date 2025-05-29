resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = var.instance_type
  tags = {
    Name = "${var.instance_name}"   # ← 뒤에 v2 같은 거 붙여서 이름만 바꿔줘
  }
}
provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "app_repo" {
  name = var.ecr_repo_name
}

resource "aws_codebuild_project" "build_app" {
  name          = "build-${var.service_name}"
  service_role  = aws_iam_role.codebuild_role.arn

  source {
    type      = "GITHUB"
    location  = var.github_repo_url
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variables = [
      {
        name  = "REPO_URI"
        value = aws_ecr_repository.app_repo.repository_url
      }
    ]
  }
}

resource "aws_codepipeline" "pipeline" {
  name     = "pipeline-${var.service_name}"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = var.s3_bucket
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
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.build_app.name
      }
    }
  }
}
