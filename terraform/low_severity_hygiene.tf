# LOW severity hygiene gaps — missing environment/owner/project tags (NetGuard Rule 11).

resource "aws_ebs_volume" "untagged_backup_volume" {
  availability_zone = "us-east-1a"
  size              = 100
  encrypted         = false

  tags = {
    Name = "demo-untagged-backup-volume"
  }
}

resource "aws_efs_file_system" "untagged_shared_fs" {
  creation_token = "demo-untagged-efs"
  encrypted      = false

  tags = {
    Purpose = "shared-app-data"
  }
}
