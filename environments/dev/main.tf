# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


locals {
  env = "dev"
}

provider "google" {
  project = var.project_name
  region = var.region
  zone = var.zone
}

module "vpc" {
  source  = "../../modules/vpc"
  project = var.project
  env     = local.env
}

module "http_server" {
  source  = "../../modules/http_server"
  project = var.project
  subnet  = module.vpc.subnet
}

module "firewall" {
  source  = "../../modules/firewall"
  project = var.project
  subnet  = module.vpc.subnet
}
  
module "bigquery" {
  source                     = "terraform-google-modules/bigquery/google"
  version                    = "4.5.0"
  dataset_id                 = "dwh"
  dataset_name               = "dwh"
  description                = "Our main data warehouse located in the US"
  project_id                 = var.project
  location                   = "US"
  delete_contents_on_destroy = true
  tables = [
    {
      table_id           = "wikipedia_pageviews_2021",
      schema             = "schemas/pageviews_2021.schema.json",
      time_partitioning  = null,
      range_partitioning = null,
      expiration_time    = 2524604400000, # 2050/01/01
      clustering = [ "wiki", "title" ],
      labels = {
        env      = "devops"
        billable = "true"
        owner    = "joedoe"
      },
    }
  ]
  dataset_labels = {
    env      = "dev"
    billable = "true"
    owner    = "janesmith"
  }
}
  
module "gcs_buckets" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "1.7.2"

  names       = ["dataops-terraform-tfstate"]
  prefix = "dataops-prefix"
  project_id = var.project
  #location   = "us-east1"

  set_admin_roles = true
  versioning = {
    first = true
  }
}
  
resource "google_cloudbuild_trigger" "example" {
  project = "example"
  name    = "example"

  source_to_build {
    repo_type = "GITHUB"
    uri       = "https://github.com/binxio/scheduled-trigger-example"
    ref       = "refs/heads/main"
  }

  git_file_source {
    path = "cloudbuild.yaml"

    repo_type = "GITHUB"
    uri       = "https://github.com/binxio/scheduled-trigger-example"
    revision  = "refs/heads/main"
  }
}

resource "google_project_service" "registry" {
  service = "containerregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "run" {
  service = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_cloud_run_service" "my-service" {
  name = var.service_name
  location = var.region

  template  {
    spec {
    containers {
            image = "gcr.io/cloudrun/hello"
    }
  }
  }
  depends_on = [google_project_service.run]
}

resource "google_cloud_run_service_iam_member" "allUsers" {
  service  = google_cloud_run_service.my-service.name
  location = google_cloud_run_service.my-service.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_service_account" "build_runner" {
  project      = "example"
  account_id   = "build-runner"
}
  
resource "google_project_iam_custom_role" "build_runner" {
  project     = "example"
  role_id     = "buildRunner"
  title       = "Build Runner"
  description = "Grants permissions to trigger Cloud Builds."
  permissions = ["cloudbuild.builds.create"]
}

resource "google_project_iam_member" "build_runner_build_runner" {
  project = "example"
  role    = google_project_iam_custom_role.build_runner.name
  member  = "serviceAccount:${google_service_account.build_runner.email}"
}
